# grpc-gateway-generator

A script to generate a ready to use [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway), with swagger, by just providing the protos and a simple configuration file.

## Installation

### Prerequisites

- If you don't have go installed, [install go](https://golang.org/doc/install)
- Install [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) dependencies. (ProtocolBuffers 3.0.0-beta-3 or later), and the following packages:

```bash
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
./generate.sh protos-path config-file destination-path  
```

## Step by step guide

- First, create your protos and add the corresponding annotations. You can see the [grpc-gateway documentation](https://github.com/grpc-ecosystem/grpc-gateway#usage) or the sample file in [examples/protos/myapp](https://github.com/devsu/grpc-gateway-generator/blob/master/example/protos/myapp/sample.proto) for an example.
- Then you need to create a config file. 

  The config file has two sections: `gateway` and `backends`. 
  
  In the gateway section, you define the address that the gateway will listen into.
  
  The backends is an array of objects with 3 properties: 
  
    - `folder`: name of the package, but as folder. It's the place where the stubs will be auto-generated.
    - `backend`: what addres the GRPC server is running.
    - `basePath`: what's the base url for the services on this proto file.

  See [config.json](https://github.com/devsu/grpc-gateway-generator/blob/master/example/config.json) for an example of how it should look.
- Then you just need to run the command with the right arguments.

  For example, to create a grpc-gateway using the information in the example:

  ```bash
  ./generate.sh example/protos example/config.json example/generated 
  ```
  
## License and Credits

Devsu LLC. MIT License. Copyright 2017. 

Built by the [GRPC experts](https://devsu.com) at Devsu.