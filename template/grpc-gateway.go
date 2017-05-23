package main

import (
  "net/http"
  "github.com/golang/glog"
  "github.com/grpc-ecosystem/grpc-gateway/runtime"
  "golang.org/x/net/context"
  "google.golang.org/grpc"
  // ADD IMPORTS HERE
)

type RegisterFromEndpoint func(context.Context, *runtime.ServeMux, string, []grpc.DialOption) error

func loadEndpoint(ctx context.Context, serverMux *http.ServeMux, endpointConfig string, path string, registerFunction RegisterFromEndpoint) error {
  gwmux := runtime.NewServeMux()
  opts := []grpc.DialOption{grpc.WithInsecure()}
  err := registerFunction(ctx, gwmux, endpointConfig, opts)
  if err != nil {
    glog.Fatalf("failed to register endpoint: %v", err)
  }
  serverMux.Handle(path, gwmux)
  return err
}

func run() error {
  ctx := context.Background()
  ctx, cancel := context.WithCancel(ctx)
  defer cancel()

  serverMux := http.NewServeMux()
  fs := http.FileServer(http.Dir("swagger-ui"))
  serverMux.Handle("/help/", http.StripPrefix("/help/", fs))

  fsDefinitions := http.FileServer(http.Dir("definitions"))
  serverMux.Handle("/definitions/", http.StripPrefix("/definitions/", fsDefinitions))

  // ADD ENDPOINTS HERE

  return http.ListenAndServe("LISTEN", serverMux)
}

func main() {
  defer glog.Flush()

  if err := run(); err != nil {
    glog.Fatal(err)
  }
}
