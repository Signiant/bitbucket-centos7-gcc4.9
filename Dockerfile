FROM signiant/docker-jenkins-centos-base:centos7-java8
MAINTAINER devops@signiant.com

ENV BUILD_USER bldmgr
ENV BUILD_USER_GROUP users


# Set the timezone
RUN unlink /etc/localtime
RUN ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# Install aws
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
RUN unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2
RUN /tmp/awscliv2/aws/install
RUN rm -rf /tmp/awscliv2*

# Install maven
ENV MAVEN_VERSION 3.2.1
RUN curl -fsSL http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven

# Install yum packages required for build node
COPY yum-packages.list /tmp/yum.packages.list
RUN chmod +r /tmp/yum.packages.list
RUN yum install -y -q `cat /tmp/yum.packages.list`

# Install c/c++ development tools
RUN yum install -y centos-release-scl 
RUN yum install -y devtoolset-9
RUN scl enable devtoolset-9 bash
RUN printf "\nsource scl_source enable devtoolset-9\n" >> /root/.bashrc
RUN printf "\nsource scl_source enable devtoolset-9\n" >> /home/$BUILD_USER/.bashrc

RUN mv /usr/bin/cmake /usr/bin/cmake2
RUN mv /usr/bin/ccmake /usr/bin/ccmake2
RUN wget https://cmake.org/files/v3.12/cmake-3.12.0-Linux-x86_64.tar.gz -O /tmp/cmake-3.12.0-Linux-x86_64.tar.gz
RUN cd /usr/local/bin && \
	tar -xzf /tmp/cmake-3.12.0-Linux-x86_64.tar.gz
RUN ln -s /usr/local/bin/cmake-3.12.0-Linux-x86_64/bin/cmake /usr/bin/cmake

# Install jboss
RUN wget --no-check-certificate http://sourceforge.net/projects/jboss/files/JBoss/JBoss-5.1.0.GA/jboss-5.1.0.GA.zip/download -O /tmp/jboss-5.1.0.GA.zip
RUN unzip -q /tmp/jboss-5.1.0.GA.zip -d /usr/local
RUN rm -f /tmp/jboss-5.1.0.GA.zip

# Install Ruby
RUN cd /tmp && \
    wget https://cache.ruby-lang.org/pub/ruby/2.7/ruby-2.7.8.tar.gz && \
    tar xvfz ./ruby-2.7.8.tar.gz && \
    cd ruby-2.7.8 && \
    ./configure --prefix=/usr && \
    make && \
    make install

# Install Compass
RUN gem install json_pure
# RUN gem update --system
RUN gem install "rubygems-update:<3.0.0" --no-document
RUN update_rubygems
RUN gem install rb-inotify -v 0.9.10
RUN gem install compass

# Install the latest version of git
RUN cd /tmp && \
    wget https://github.com/git/git/archive/v2.7.0.tar.gz && \
    tar xvfz ./v2.7.0.tar.gz && \
    cd git-2.7.0 && \
    make configure && \
    ./configure --prefix=/usr && \
    make && \
    make install

# Install Python 2.7.X for Umpire
RUN cd /tmp && \
    wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz && \
    tar xvfz Python-3.12.0.tgz && \
    cd Python-3.12.0 && \
    ./configure --prefix=/usr/local && \
    make && \
    make altinstall

RUN python3.12 -m pip install --upgrade pip

ENV UMPIRE_VERSION 0.5.5
# Install umpire
RUN python3.12 -m pip install umpire==${UMPIRE_VERSION}

# upgrade npm, node and install phantomjs
RUN npm install -g n
RUN npm install -g npm
RUN n 6.10.0
RUN npm install -g phantomjs

# Remove any trace of java7
RUN yum remove -y java-1.7.0-openjdk.x86_64 java-1.7.0-openjdk-headless.x86_64

# Make sure anything/everything we put in the build user's home dir is owned correctly
RUN chown -R $BUILD_USER:$BUILD_USER_GROUP /home/$BUILD_USER

EXPOSE 22

# This entry will either run this container as a jenkins slave or just start SSHD
# If we're using the slave-on-demand, we start with SSH (the default)

# Default Jenkins Slave Name
ENV SLAVE_ID JAVA_NODE
ENV SLAVE_OS Linux

ADD start.sh /
RUN chmod 777 /start.sh

CMD ["sh", "/start.sh"]
