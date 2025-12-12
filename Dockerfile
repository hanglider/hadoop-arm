# Hadoop 3.3.6 image for ARM64 / x86_64
#FROM openjdk:11-jdk-slim
FROM eclipse-temurin:11-jdk

ARG HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop

# Install base packages and Hadoop
RUN apt-get update && \
    apt-get install -y curl wget tar bash procps net-tools openssh-client openssh-server && \
    mkdir -p /opt && \
    wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm hadoop-${HADOOP_VERSION}.tar.gz && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Detect and export JAVA_HOME dynamically
RUN JAVA_PATH=$(dirname $(dirname $(readlink -f $(which java)))) && \
    echo "export JAVA_HOME=${JAVA_PATH}" >> /etc/profile && \
    echo "export PATH=\$PATH:${JAVA_PATH}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin" >> /etc/profile

ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

WORKDIR /opt/hadoop
CMD ["bash", "-lc", "echo 'Container ready.' && hadoop version && sleep infinity"]
