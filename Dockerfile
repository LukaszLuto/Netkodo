FROM ubuntu:20.04

RUN apt-get -y update
RUN apt-get -y install sudo
RUN sudo apt -y install gpg curl software-properties-common

RUN sudo gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN sudo apt-add-repository -y ppa:rael-gc/rvm
RUN sudo apt-get -y update
RUN sudo apt-get -y install rvm

RUN useradd -ms /bin/bash hosting
RUN usermod -a -G rvm hosting
RUN echo 'hosting ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER hosting
WORKDIR /home/hosting

RUN echo 'source "/etc/profile.d/rvm.sh"' >> ~/.bashrc
RUN /bin/bash -i -c "rvm install ruby-3.3.0"

CMD ["/bin/bash", "-l"]
