FROM ubuntu:24.04

# обновляем пакеты ubuntu
RUN apt-get update && apt-get install -y sudo adduser nano

# создаём пользователя hdoop, в котором сохраним все наши пакеты (hadoop, hive и jupyter)
RUN adduser --disabled-password --gecos '' hdoop
RUN adduser hdoop sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER hdoop
WORKDIR /home/hdoop

ARG HOME_DIR=/home/hdoop

EXPOSE 9870 9864 8088

# устанавливаем openjdk 11 версии, поскольку hadoop-3.4.1 не поддерживает версии новее)
RUN sudo apt install -y openjdk-11-jdk wget
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

# установка hadoop-3.4.1, начиная с openssh
RUN sudo apt install openssh-server -y
RUN ssh-keygen -t rsa -P '' -f $HOME_DIR/.ssh/id_rsa && \
    cat $HOME_DIR/.ssh/id_rsa.pub >> $HOME_DIR/.ssh/authorized_keys && \
    chmod 0600 $HOME_DIR/.ssh/authorized_keys
COPY ./ssh_config $HOME_DIR/.ssh/config

# скачиваем hadoop и распаковываем архив
RUN wget https://dlcdn.apache.org/hadoop/common/hadoop-3.4.1/hadoop-3.4.1.tar.gz
RUN tar xzf hadoop-3.4.1.tar.gz

# настраиваем переменные окружения hadoop
ENV HADOOP_HOME=/home/hdoop/hadoop-3.4.1
ENV HADOOP_INSTALL=$HADOOP_HOME
ENV HADOOP_MAPRED_HOME=$HADOOP_HOME
ENV HADOOP_COMMON_HOME=$HADOOP_HOME
ENV HADOOP_HDFS_HOME=$HADOOP_HOME
ENV YARN_HOME=$HADOOP_HOME
ENV HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
ENV PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
ENV HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"

RUN echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> $HOME_DIR/hadoop-3.4.1/etc/hadoop/hadoop-env.sh

# в этой папке лежат *-site.xml файлы, в конфигурациях, которые работают
COPY ./Configs/. $HOME_DIR/hadoop-3.4.1/etc/hadoop

# в некоторых *-site.xml файлах прописаны рабочие каталоги, здесь мы их создаём
RUN mkdir $HOME_DIR/tmpdata
RUN mkdir $HOME_DIR/dfsdata
RUN mkdir $HOME_DIR/dfsdata/namenode
RUN mkdir $HOME_DIR/dfsdata/datanode

# скачиваем hive-4.0.1 (важный момент - здесь и далее скачиваем не самые свежие версии, поскольку hadoop-3.4.1 работает с jdk-11, не более. а более свежие версии других приложений требуют более свежие версии jdk)
RUN wget https://dlcdn.apache.org/hive/hive-4.0.1/apache-hive-4.0.1-bin.tar.gz
RUN tar xzf apache-hive-4.0.1-bin.tar.gz

# настраиваем переменные окружения для hive
ENV HIVE_HOME="/home/hdoop/apache-hive-4.0.1-bin"
ENV PATH=$PATH:$HIVE_HOME/bin

# замечу, что для работы hive нужно было дополнительно настроить core-site.xml, что уже было сделано, так что здесь этот момент опускается

# уже в рамках контейнера можно попробовать настроить hive-site.xml, но для наших задач это не имеет смысла. Однако если хотите, то в контейнере нужно выполнить следующие команды
# cp $HIVE_HOME/conf/hive-default.xml hive-site.xml # создаёт hive-site из шаблона
# nano $HIVE_HOME/conf/hive-site.xml открывает файл конфигурации в редакторе
# здесь в теории нужно менять hive.metastore.warehouse.dir

# инициализируем схему метаданных
WORKDIR $HIVE_HOME
RUN bin/schematool -dbType derby -initSchema

# устанавливаем пакеты для spark и скачиваем сам spark-3.5.6
WORKDIR /home/hdoop
RUN sudo apt install scala git -y
RUN wget https://dlcdn.apache.org/spark/spark-3.5.6/spark-3.5.6-bin-hadoop3.tgz
RUN tar xvf spark-*.tgz
RUN sudo mv spark-3.5.6-bin-hadoop3 /opt/spark

# настраиваем переменные окружения для spark
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENV PYSPARK_PYTHON=/usr/bin/python3

# скачиваем пакеты python для работы с pyspark (в т.ч. Jupyter Notebook)
RUN sudo apt install -y software-properties-common 
RUN sudo add-apt-repository ppa:deadsnakes/ppa
RUN sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip
RUN python3 -m venv $HOME_DIR/jupyter_env
COPY requirements.txt $HOME_DIR
# ENV PATH="$HOME_DIR/jupyter_env:$PATH"
RUN . $HOME_DIR/jupyter_env/bin/activate && pip3 install --no-cache-dir -r $HOME_DIR/requirements.txt
# RUN sudo pip install jupyter findspark

RUN rm $HOME_DIR/hadoop-3.4.1.tar.gz && \
    rm $HOME_DIR/apache-hive-4.0.1-bin.tar.gz && \
    rm $HOME_DIR/spark-3.5.6-bin-hadoop3.tgz

EXPOSE 10000 10002 8080

# копируем sh скрипт, который запускает все необходимые программы в нашем контейнере
COPY entrypoint.sh $HOME_DIR
ENTRYPOINT ["/home/hdoop/entrypoint.sh"]
