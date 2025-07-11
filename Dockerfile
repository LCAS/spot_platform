# syntax = devthefuture/dockerfile-x:v1.4.2
ARG BASE_IMAGE=lcas.lincoln.ac.uk/lcas/ros-docker-images:jammy-cuda12.2-humble-2

FROM ${BASE_IMAGE} AS base

# making the standard global variables available for target-specific builds
ARG TARGETARCH

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "building for ${TARGETARCH}"

# Conditionally add a repository for arm64 architecture (as Gazebosim is not available for arm64 by default)
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
    add-apt-repository -s -y ppa:openrobotics/gazebo11-non-amd64; \
    fi

# Copy the list of APT packages to be installed from the local directory to the container
COPY .docker/apt-packages.lst /tmp/apt-packages.lst

# Update the package list, upgrade installed packages, install the packages listed in apt-packages.lst,
# remove unnecessary packages, clean up the APT cache, and remove the package list to reduce image size
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -qq -y --no-install-recommends \
        `cat /tmp/apt-packages.lst` && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# The vendor_base stage sets up the base image and includes additional Dockerfiles
# for various dependencies that are not ROS packages. 
# This stage is used to build a foundation with all
# necessary libraries and tools required.
#
# - FROM base AS vendor_base: Uses the 'base' image as the starting point and names this stage 'vendor_base'.
# - INCLUDE .docker/glog.dockerfile: Adds the Google Logging library setup from the specified Dockerfile.
# - INCLUDE .docker/magic_enum.dockerfile: Adds the Magic Enum library setup from the specified Dockerfile.
FROM base AS vendor_base
INCLUDE .docker/glog.dockerfile
INCLUDE .docker/magic_enum.dockerfile

# This stage is named 'sourcefilter' and is based on the 'base' image.
# It performs the following actions:
# 1. Creates a directory /tmp/src/ to store source files.
# 2. Copies all package.xml files from various nested directories within ./src/ to /tmp/src/_workspace/src/_pkgs_xmls.
# 3. Copies all .repos files from the ./.docker directory to /tmp/.docker/.
# 4. Changes the working directory to /tmp/src and imports repositories listed in the .repos files using vcs.
# 5. If the target architecture is arm64, it imports additional repositories from gazebo_ros_pkgs.repos-arm64.
# 6. Pulls the latest changes for all imported repositories.
FROM base as sourcefilter
RUN mkdir -p /tmp/src/
COPY ./src/*/package.xml /tmp/src/_workspace/src/_pkgs_xmls
COPY ./src/*/*/package.xml /tmp/src/_workspace/src/_pkgs_xmls
COPY ./src/*/*/*/package.xml /tmp/src/_workspace/src/_pkgs_xmls
COPY ./src/*/*/*/*/package.xml /tmp/src/_workspace/src/_pkgs_xmls
COPY ./.docker/*.repos* /tmp/.docker/
RUN cd /tmp/src && for r in /tmp/.docker/*.repos; do vcs import < $r ; done
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
        cd /tmp/src; \
        vcs import < /tmp/.docker/gazebo_ros_pkgs.repos-arm64; \
    fi
RUN cd /tmp/src && vcs pull
# remove everything that isn't package.xml
RUN find /tmp/src -type f \! -name "package.xml" -print | xargs rm -rf

# This Dockerfile is designed to build a ROS (Robot Operating System) workspace.
# It consists of multiple stages to optimize the build process and reduce the final image size.
# 
# The stages are as follows:
# 1. depinstaller: Installs the necessary dependencies for the ROS workspace by copying a reduced source tree and using rosdep.
# 2. depbuilder: Copies additional repository and script files, imports the source tree, and builds the workspace.
# 
# The output of depbuilder is a Docker image with the ROS workspace built and ready for use.
FROM vendor_base as depinstaller
# copy the reduced source tree (only package.xml) from previous stage
COPY --from=sourcefilter /tmp/src /tmp/src
RUN rosdep update --rosdistro=${ROS_DISTRO} && apt-get update
RUN rosdep install --from-paths /tmp/src --ignore-src -r -y && rm -rf /tmp/src && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/src

FROM depinstaller as depbuilder
COPY .docker/*.repos* .docker/*.sh /tmp/.docker/

# get the source tree and build it (include gazebo only for arm64 platform as it is not available for arm64)
# see https://github.com/gazebosim/gazebo-classic/issues/3236
RUN mkdir -p /opt/ros/lcas/src && \
    cd /opt/ros/lcas/src && \
    for r in /tmp/.docker/*.repos; do vcs import < $r ; done
RUN  if [ "${TARGETARCH}" = "arm64" ]; then cd /opt/ros/lcas/src; vcs import < /tmp/.docker/gazebo_ros_pkgs.repos-arm64; fi

RUN . /opt/ros/humble/setup.sh && \
    apt update && \
    rosdep --rosdistro=${ROS_DISTRO} update && \
    cd /opt/ros/lcas/src && \
    vcs pull && \
    rosdep install --from-paths . -i -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# build the workspace but only until limo_gazebosim to avoid building the hardware specific packages
RUN cd /opt/ros/lcas; colcon build && \
    rm -rf /opt/ros/lcas/src/ /opt/ros/lcas/build/ /opt/ros/lcas/log/

# configure the devcontainer without the sources in this repository (all dependencies ready to go)
FROM depbuilder as devcontainer

COPY .docker/bash.alias /tmp/bash.alias
RUN cat /tmp/bash.alias >> /etc/bash.bashrc

# now also copy in all sources and build and install them
FROM devcontainer as compiled

# Copy your source code
COPY ./src /opt/ros/lcas/local-src/

# Setup spot_ros2
WORKDIR /opt/ros/lcas/local-src/spot_ros2
RUN bash install_spot_ros2.sh
RUN colcon build
RUN mv install/ /opt/ros/lcas/spot_ros2

# Setup ublox
WORKDIR /opt/ros/lcas/local-src/ros2-ublox-zedf9p
RUN colcon build
RUN mv install/ /opt/ros/lcas/ros2-ublox-zedf9p

RUN rm -rf /opt/ros/lcas/local-src/
    
# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Give ROS access to serial devices
RUN usermod -aG dialout ros
USER ros

# Install https://github.com/semuconsulting/PyGPSClient
RUN pip install --upgrade pygpsclient

# Setup bash aliases
RUN echo "source /opt/ros/lcas/install/setup.bash" >> ~/bash.bashrc # other lcas repos
RUN echo "source /opt/ros/lcas/spot_ros2/setup.bash" >> ~/.bashrc # spot
RUN echo "source /opt/ros/lcas/ros2-ublox-zedf9p/setup.bash" >> ~/.bashrc # ublox
RUN echo "export PS1='\[\e[0;33m\]spot_platform ➜ \[\e[0;32m\]\u@\h\[\e[0;34m\]:\w\[\e[0;37m\]\$ '" >> ~/.bashrc

WORKDIR /home/ros
ENV SHELL=/bin/bash
