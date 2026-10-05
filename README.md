# Dr Robotnik's Ring Racers Server

> Containerized version of Ring Racers. Designed for Podman first, please convert to docker as you see fit.

<p align="center">
  <img src="https://cdn.discordapp.com/attachments/298839130144505858/512450353124343808/unknown.png" width="100%" alt="SRB2Kart">
</p>

Containerized version of [Ring Racers](https://www.kartkrew.org/), a kart racing total conversion mod of the game Doom. For more details on the project, please visit the previous hyperlink.

## Usage

If you're using podman compose, you can simply type the following:

```
podman compose up -d && podman compose logs -f
```

This should be enough to kickstart your server with default configurations.



### Data Volume

The `~/.ringracers` directory is symlinked to `/data` in the container. You can bind-mount a RingRacers configuration directory (with configuration files, mods, etc.) on the host machine to the `/data` directory inside the container. E.G.

```yaml
# ...
    volumes:
    #z,U gives appropriate permissions according to podman mount arguments
      - ./ringdata:/data:z,U
# ...
```

If you're having permission issues with the `ringdata` folder, which can prevent the server from booting correctly, you should to run the following command:

```
podman unshare chown -R 10001:10001 ./ringdata
```

User `10001` is the `ringracers` user. Podman uses uidmaps to change ids associated with a user inside the container, so user directories will generally be inaccessible from inside the container by design. `unshare` lets us give specific permission for this folder and all of its contents. 

All files found in `ringracers/addons` will automatically be loaded into the game executable and enabled on the server.  


## License

This project is licensed under the [GPLv2 License](./LICENSE).
