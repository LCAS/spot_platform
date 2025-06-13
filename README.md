# 🐶 L-CAS Spot Platform

A containerised, clean ROS2 workspace for the [Boston Dynamics Spot Robot Dog](https://bostondynamics.com/products/spot/).

> [!WARNING]  
> This is currently in-development and should not be expected to fully function or be ready for non-research activities.

## Using the Docker image for the real robot

### Setup

First, you will need to get a computer that is going to act as our gateway to Spot. We have an Intel NUC that is mounted to the back of our Spot. This is what we have nicknamed the 'backpack'.

This machine needs an Operating System installed, for this - we are using Ubuntu 22.04 so it can give the container the best chance, but this can be something else if you prefer. We will setup the computer with the username of `spot`.

Configure the machine for SSH. And get connected.

Then git clone this repository into the home folder (`/home/spot/spot_platform`).

Then cd into the repository and then into the configs folder, (`/home/spot/spot_platform/configs`).

Then copy the example `.env` file (`cp .env.example .env`). And then edit it to include the following values:

- `ROBOT_NAME`: How should you call your spot, do you have multiple? If not - we can call this just `SPOT`
- `BOSDYN_CLIENT_USERNAME`: This is the password for connecting to Spot, by default its the one in the battery compartment, if it has changed on your Spot you should be informed when you're inducted!
- `BOSDYN_CLIENT_PASSWORD`: This is the password for connecting to Spot, by default its the one in the battery compartment, if it has changed on your Spot you should be informed when you're inducted!
- `SPOT_IP`: Leave this as `192.168.50.3` unless you are doing something special ([read the Spot Network wiki page first!](https://github.com/LCAS/spot_platform/wiki/Spot-Network))

Also, If you want to use your NVIDIA GPU inside the container, Docker needs to be configured with the [NVIDIA runtime](https://lncn.ac/nvct) running and tested.

Now you have setup the container, you should start it!

### Starting the Container

1. Navigate to the `configs` directory of this repository:
```bash
cd configs
```

2. Start the container in detached mode and view logs:
```bash
docker compose up -d && docker compose logs -f
```

*Note:* By default, the containers here are restarted at boot time

### Accessing the virtual desktop

1. Find the IP address of your robot, let's name it `SPOT_IP`
2. Open your browser at address http://`SPOT_IP`:5801/, and connect


### Stopping the container

1. `docker compose down`, again in the `configs` directory


### Using Spot with ROS

Once you're connected - open a terminal and run `walkies` (this is an alias) and give it a go!

You can setup your ROS Workspace on the native computer by using the folder `/home/ros/robot_home` which is a link to your local folder `/home/spot/`, this is using a [Docker volume](https://docs.docker.com/engine/storage/volumes/). Create a folder such as `my_ws` inside of this.

Now you have done your initial setup of Spot, look at [the wiki](https://github.com/LCAS/spot_platform/wiki) for more help on what to do!