package main

import (
	"context"
	"fmt"
	"os"
	"time"

	log "github.com/Sirupsen/logrus"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/coreos/etcd/clientv3"
	"github.com/crewjam/awsregion"
	"github.com/crewjam/ec2cluster"
)

var cli *clientv3.Client

func getInstance(m *ec2cluster.LifecycleMessage) (*ec2.Instance, error) {
	awsSession := session.New()
	if region := os.Getenv("AWS_REGION"); region != "" {
		awsSession.Config.WithRegion(region)
	}
	awsregion.GuessRegion(awsSession.Config)

	ec2svc := ec2.New(awsSession)
	resp, err := ec2svc.DescribeInstances(&ec2.DescribeInstancesInput{
		InstanceIds: []*string{aws.String(m.EC2InstanceID)},
	})

	if err != nil {
		return nil, err
	}

	if len(resp.Reservations) != 1 || len(resp.Reservations[0].Instances) != 1 {
		return nil, fmt.Errorf("Cannot find instance: %s", m.EC2InstanceID)
	}

	return resp.Reservations[0].Instances[0], nil
}

func lifecycleOnTerminate(m *ec2cluster.LifecycleMessage) (shouldContinue bool, err error) {
	resp, err := cli.MemberList(context.Background())
	if err != nil {
		log.Fatalf("ERROR: Could not list cluster members: %s", err)
	}
	newInstance, err := getInstance(m)
	if err != nil {
		log.Fatalf("ERROR: Could not get EC2 Instance: %s", err)
	}

	for _, member := range resp.Members {
		if member.Name == m.EC2InstanceID {
			log.Info("Removing %s at %s", m.EC2InstanceID, newInstance.PrivateIpAddress)
			cli.MemberRemove(context.Background(), member.ID)
			return true, nil
		}
	}
	return true, nil
}

func lifecycleOnLaunch(m *ec2cluster.LifecycleMessage) (shouldContinue bool, err error) {
	resp, err := cli.MemberList(context.Background())
	if err != nil {
		log.Fatalf("ERROR: Could not list cluster members: %s", err)
	}
	newInstance, err := getInstance(m)
	if err != nil {
		log.Fatalf("ERROR: Could not get EC2 Instance: %s", err)
	}
	for _, member := range resp.Members {
		if member.Name == m.EC2InstanceID {
			log.Infof("Instance %s already in cluster...skipping 'add'", m.EC2InstanceID)
			return true, nil
		}
	}
	peer_urls := []string{fmt.Sprintf("http://%s:2380", newInstance.PrivateIpAddress)}
	log.Infof("Adding new member: %s", peer_urls)
	cli.MemberAdd(context.Background(), peer_urls)
	return true, nil
}

// handleLifecycleEvent is invoked whenever we get a lifecycle terminate message. It removes
// terminated instances from the etcd cluster.
func handleLifecycleEvent(m *ec2cluster.LifecycleMessage) (shouldContinue bool, err error) {
	switch m.LifecycleTransition {
	case "autoscaling:EC2_INSTANCE_TERMINATING":
		return lifecycleOnTerminate(m)
	case "autoscaling:EC2_INSTANCE_LAUNCHING":
		return lifecycleOnLaunch(m)
	}
	return true, nil
}

func watchLifecycleEvents(s *ec2cluster.Cluster, localInstance *ec2.Instance, client clientv3.Client) {
	etcdLocalURL = fmt.Sprintf("http://%s:2379", *localInstance.PrivateIpAddress)
	cli = &client
	for {
		queueUrl, err := s.LifecycleEventQueueURL()

		// The lifecycle hook might not exist yet if we're being created
		// by cloudformation.
		if err == ec2cluster.ErrLifecycleHookNotFound {
			log.Printf("WARNING: %s", err)
			time.Sleep(10 * time.Second)
			continue
		}

		if err != nil {
			log.Fatalf("ERROR: LifecycleEventQueueUrl: %s", err)
		}
		log.Printf("Found Lifecycle SQS Queue: %s", queueUrl)

		err = s.WatchLifecycleEvents(queueUrl, handleLifecycleEvent)

		if err != nil {
			log.Fatalf("ERROR: WatchLifecycleEvents: %s", err)
		}
		panic("not reached")
	}
}
