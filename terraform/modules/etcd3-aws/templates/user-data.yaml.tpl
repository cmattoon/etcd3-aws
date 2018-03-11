#cloud-config
coreos:
  units:
    - name: etcd3-aws.service
      command: start
      content: |
        [Unit]
        Description=Configures and runs etcd in AWS

        [Install]
        WantedBy=multi-user.target

        [Service]
        Restart=always
        ExecStart=/usr/bin/docker run --name etcd3-aws \
            -e ETCD_BACKUP_BUCKET=${backup_bucket_name} \
            -e ETCD_BACKUP_KEY=${backup_key} \
            -p 2379:2379 -p 2380:2380 \
            -v /var/lib/etcd2:/var/lib/etcd2 \
            --rm cmattoon/etcd3-aws

        ExecStop=/usr/bin/docker rm -f etcd3-aws

    - name: cfn-signal.service
      command:  start
      enable: true
      content: |
        [Unit]
        Description=CloudFormation Signal Ready
        After=etcd3-aws.service
        Requires=etcd3-aws.service
        
        [Install]
        WantedBy=multi-user.target
        
        [Service]
        Type=oneshot
        ExecStart=/bin/bash -c 'set -ex; eval $(docker run crewjam/ec2cluster); docker run --rm crewjam/awscli cfn-signal --resource MasterAutoscale --region ${region} || true;'
    
