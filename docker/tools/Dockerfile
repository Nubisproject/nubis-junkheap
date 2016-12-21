FROM centos:7

RUN yum -y install epel-release centos-release-scl-rh centos-release-scl 
RUN yum -y update
RUN yum -y install curl python2-pip unzip git

ARG packer_version=0.12.1
ARG github_changelog_generator_version=1.14.2
ARG librarian_puppet_version=2.2.3
ARG puppet_version=4.8.1

# Install packer
RUN curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/${packer_version}/packer_${packer_version}_linux_amd64.zip
RUN cd /usr/local/bin && unzip /tmp/packer.zip && rm /tmp/packer.zip

# Install jq
RUN yum -y install jq-1.5

# Install AWS CLI
RUN yum -y install awscli-1.11.10-1.el7

# Install nubis-builder
RUN  git clone https://github.com/nubisproject/nubis-builder.git /opt/nubis-builder
ADD variables.json /opt/nubis-builder/secrets/variables.json

# Install Ruby for gems
RUN yum --enablerepo=centos-sclo-rh -y install rh-ruby22 rh-ruby22-rubygems
ADD rh-ruby22.sh /etc/profile.d/rh-ruby22.sh

# Install github changelog generator
RUN source scl_source enable rh-ruby22 && gem install -V github_changelog_generator -v ${github_changelog_generator_version}

# Install librarian puppet
RUN source scl_source enable rh-ruby22 && gem install -V librarian-puppet -v ${librarian_puppet_version}

RUN source scl_source enable rh-ruby22 && gem install -V puppet -v ${puppet_version}

ENV PATH=/bin:/usr/bin:/usr/local/bin:/opt/nubis-builder/bin

RUN mkdir /code
ADD nubis-clone /usr/bin/nubis-clone

RUN yum clean all

RUN rm /root/anaconda-ks.cfg
