#!/usr/bin/env bash
if [ "$#" -ne 3 ]; then
  echo "USAGE: ./generate.sh protos-path config-file destination-path"
  exit 1
fi

PROTOS_PATH=${1}
CONFIG_FILE=${2}
DESTINATION_PATH=${3}
TEMPLATE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/template"

echo "GENERATING GATEWAY:"
echo " -> protos from '${PROTOS_PATH}'"
echo " -> config from '${CONFIG_FILE}'"
echo " -> template from '${TEMPLATE_PATH}'"
echo " -> into '${DESTINATION_PATH}'"

STUBS_PATH=${DESTINATION_PATH}/stubs
SWAGGER_PATH=${DESTINATION_PATH}/swagger-ui
DEFINITIONS_PATH=${DESTINATION_PATH}/definitions

mkdir -p $DESTINATION_PATH

echo "CLEANING UP..."
rm -rf ${STUBS_PATH}
rm -rf ${SWAGGER_PATH}
rm -rf ${DEFINITIONS_PATH}
rm -f grpc-gateway.go

echo "USING..."
protoc --version

echo "COPYING... template files"
cp -r ${TEMPLATE_PATH}/* ${DESTINATION_PATH}
mkdir -p ${STUBS_PATH}
mkdir -p ${DEFINITIONS_PATH}

echo "PREPARING... Moving annotations.proto and http.proto to another folder temporarily"
mv ${PROTOS_PATH}/google/api/annotations.proto ${DESTINATION_PATH}
mv ${PROTOS_PATH}/google/api/http.proto ${DESTINATION_PATH}

echo "GENERATING... stubs go"
find ${PROTOS_PATH} -type f -name "*.proto" -exec protoc -I${PROTOS_PATH} \
  --proto_path=${PROTOS_PATH} \
  -I${GOPATH}/src \
  -I${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --go_out=plugins=grpc:${STUBS_PATH} \
	{} \;

echo "GENERATING... reverse-proxy"
find ${PROTOS_PATH} -type f -name "*.proto" -exec protoc -I${PROTOS_PATH} \
  --proto_path=${PROTOS_PATH} \
  -I${GOPATH}/src \
  -I${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --grpc-gateway_out=logtostderr=true:${STUBS_PATH} \
	{} \;

echo "GENERATING... swagger definitions"
find ${PROTOS_PATH} -type f -name "*.proto" -exec protoc -I${PROTOS_PATH} \
  --proto_path=${PROTOS_PATH} \
  -I${GOPATH}/src \
  -I${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --swagger_out=logtostderr=true:${DEFINITIONS_PATH} \
  {} \;

echo "RESTORING... Moving back annotations.proto and http.proto"
mv ${DESTINATION_PATH}/annotations.proto ${PROTOS_PATH}/google/api/
mv ${DESTINATION_PATH}/http.proto ${PROTOS_PATH}/google/api/

echo "GENERATING... swagger list of files"
echo "[" >> ${DEFINITIONS_PATH}/list.json
find ${DEFINITIONS_PATH} -type f -name "*.json" -exec echo "\"{}\"," >> ${DEFINITIONS_PATH}/list.json \;
sed -i '' -e "s|${DESTINATION_PATH}||g" \
  -e '/list.json",/d' \
  -e '$s/,$//g' \
  "${DEFINITIONS_PATH}/list.json"
echo "]" >> ${DEFINITIONS_PATH}/list.json

echo "MODIFYING... swagger files, to include authorization bearer"
SECURITY_DEFINITIONS='"securityDefinitions":{"Bearer":{"type":"apiKey","name":"Authorization","in":"header"}}';
find ${DEFINITIONS_PATH} -type f -name "*.json" -exec sed -i '' -e "\$s/}/,${SECURITY_DEFINITIONS}}/" {} \;

echo "MODIFYING... grpc-gateway.go"
FOLDERS=$(cat ${CONFIG_FILE} | jq '.backends | .[] | .folder' | sed -e 's/"//g')
BACKENDS=($(cat ${CONFIG_FILE} | jq '.backends | .[] | .backend'))
BASE_PATHS=($(cat ${CONFIG_FILE} | jq '.backends | .[] | .basePath'))
COUNT=0;
for FOLDER in ${FOLDERS}
do
  sed -i '' "s|.*ADD IMPORTS HERE.*|  gw${COUNT} \"./stubs/${FOLDER}\""'\
&|' "${DESTINATION_PATH}/grpc-gateway.go"

  METHODS=$(find ${STUBS_PATH}/${FOLDER} -type f -maxdepth 1 -print | xargs grep -E "Register(.*)FromEndpoint" -ho | uniq)

  for ENDPOINT_METHOD in ${METHODS}
  do
    PARAMETERS="${BACKENDS[COUNT]}, ${BASE_PATHS[COUNT]}, gw${COUNT}.${ENDPOINT_METHOD}"
    sed -i '' -e "s|.*ADD ENDPOINTS HERE.*|  loadEndpoint(ctx, serverMux, ${PARAMETERS})"'\
&|' "${DESTINATION_PATH}/grpc-gateway.go"
  done
  COUNT=$((COUNT+1))
done

echo "CONFIGURING... grpc-gateway.go"
LISTEN=$(cat ${CONFIG_FILE} | jq '.gateway | .listen')
sed -i '' -e "s|\"LISTEN\"|${LISTEN}|" "${DESTINATION_PATH}/grpc-gateway.go"

#echo "RUNNING SERVICES..."
#
#cd /go/src/app/
#cp -r google ../google
#
#go build main.go
#go run main.go