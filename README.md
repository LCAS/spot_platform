# A containerised, clean ROS2 workspace for the Boston Dynamics Spot Robot Dog

> [!WARNING]  
> This is still a work in-progress and should be expected to not fully function.

## Using the Docker image for the real robot

## Requirements

* an environment variable `ROBOT_NAME` is expected to be defined, either in `.env` or in the environment (e.g. `~/.bashrc`)
* Docker is needed with the NIVIDA runtime running and tested


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


## 