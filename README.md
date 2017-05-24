# grpc-gateway-generator

A script to generate a ready to use [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway), with swagger, by just providing the protos and a simple configuration file.

**Status:** Alpha, it's not production ready yet. See TODO list below.

## Installation

### Prerequisites

- If you don't have go installed, [install go](https://golang.org/doc/install)
- Install [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) dependencies. (ProtocolBuffers 3.0.0-beta-3 or later), and the following packages:

```bash
go get -u google.golang.org/grpc
go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger
go get -u github.com/golang/protobuf/protoc-gen-go
```

- Install the script dependencies:

  - [jq](https://stedolan.github.io/jq/)

### Clone

```bash
git clone https://github.com/devsu/grpc-gateway-generator
```

## Usage

```bash
./generate.sh protos-path config-file project-path  
```

### Arguments

- `protos-path`: The path to the protos folder. 

  The package names of the protos files must correspond to the folder structure. For example:
   
  - `/protos/myapp/my-file.proto` must have the package `myapp`, and 
  - `/protos/myapp/mymicroservice/another-file.proto` must have the package `myapp.mymicroservice`

- `config-file`: Path to a `config.json` file. The config file has two sections: `gateway` and `backends`. 
    
  In the gateway section, you define the address that the gateway will listen into.
    
  The backends is an array of objects with 3 properties: 
    
  - `package`: name of the package.
  - `backend`: what addres the GRPC server is running.
  - `services`: An object with the services names as keys, and the base paths of the services as values. 
  
  See [config.json](https://github.com/devsu/grpc-gateway-generator/blob/master/example/config.json) for an example of how it should look:
    
   ```json
  {
    "gateway": {
      "listen": ":9090"
    },
    "backends": [
      {
        "package": "myapp",
        "backend": "localhost:3000",
        "services": {
          "GreeterService": "/sample/greeter/"
        }
      },
      {
        "package": "myapp.mysubapp",
        "backend": "localhost:3000",
        "services": {
          "AnotherGreeterService": "/sample/another-greeter/"
        }
      }
    ]
  }
  ```

- `project-path`: The path of the go project to be created. The gateway will be created in `${GOPATH}/src/${projectPath}`. Read [How to write Go Code](https://golang.org/doc/code.html) to learn how to choose a proper project path. 

## Step by step guide

- First, create your protos and add the corresponding annotations. You can see the [grpc-gateway documentation](https://github.com/grpc-ecosystem/grpc-gateway#usage) or the sample file in [examples/protos/myapp](https://github.com/devsu/grpc-gateway-generator/blob/master/example/protos/myapp/sample.proto) for an example.
- Then you need to create a config file. (See instructions above)
- Then you just need to run the command with the right arguments.

  For example, to create a grpc-gateway using the information in the example:

  ```bash
  ./generate.sh example/protos example/config.json github.com/my-user/my-gateway
  ```

## TODO

- Support TLS in both, the gateway, and the backends
- Make swagger creation optional
- Test on more OSs, currently only tested on Mac an Alpine
- Clean up the script
- Allow to configure authorization (currently it activates bearer authorization by default)
- Upgrade swagger-ui?

## License and Credits

Devsu LLC. MIT License. Copyright 2017. 

Built by the [GRPC experts](https://devsu.com) at Devsu.