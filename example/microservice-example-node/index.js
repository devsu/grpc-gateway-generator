const Condor = require('condor-framework');

const Greeter = class {
  sayHello(call) {
    return { 'greeting': `Hello ${call.request.name}`};
  }
};

const options = {
  'host': 'localhost',
  'port': 3000,
  'rootProtoPath': '../protos',
};

const server = new Condor(options);
server.add('myapp/sample.proto', 'GreeterService', new Greeter());
server.add('myapp/mysubapp/another.proto', 'AnotherGreeterService', new Greeter());
server.use((context, next) => {
  console.log(context.request);
  return next();
});
server.start();