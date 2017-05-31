#!/usr/bin/env bash
if [ "$#" -ne 3 ]; then
  echo "USAGE: ./generate.sh protos-path config-file destination-path"
  exit 1
fi

PROTOS_PATH=${1}
CONFIG_FILE=${2}
PROJECT_PATH=${3}
DESTINATION_PATH=${GOPATH}/src/${PROJECT_PATH}
TEMPLATE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/template"

OS=$(uname -s)
SED_OPTS="-i"
if [ $OS = "Darwin" ]; then
  SED_OPTS="-i .bak"
fi

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
sed ${SED_OPTS} -e "s|${DESTINATION_PATH}||g" "${DEFINITIONS_PATH}/list.json"
sed ${SED_OPTS} -e '/list.json",/d' "${DEFINITIONS_PATH}/list.json"
sed ${SED_OPTS} -e '/google\/protobuf/d' "${DEFINITIONS_PATH}/list.json"
sed ${SED_OPTS} -e '$s/,$//g' "${DEFINITIONS_PATH}/list.json"
echo "]" >> ${DEFINITIONS_PATH}/list.json

echo "MODIFYING... swagger files, to include authorization bearer"
SECURITY_DEFINITIONS='"securityDefinitions":{"Bearer":{"type":"apiKey","name":"Authorization","in":"header"}}';
find ${DEFINITIONS_PATH} -type f -name "*.json" -exec sed ${SED_OPTS} -e "\$s/}/,${SECURITY_DEFINITIONS}}/" {} \;

echo "MODIFYING... grpc-gateway.go"
PACKAGES=$(jq '.backends | .[] | .package' <${CONFIG_FILE} | sed -e 's|"||g')
COUNT=0
for PACKAGE in ${PACKAGES}
do
  FOLDER=$(sed -e 's|\.|/|g' <<< ${PACKAGE})
  BACKEND_OBJECT=$(jq '.backends | .[] | select(.package=="'${PACKAGE}'")' <${CONFIG_FILE})
  SERVICES_OBJECT=$(jq '.services' <<< ${BACKEND_OBJECT})
  BACKEND=$(jq '.backend' <<< ${BACKEND_OBJECT})

  echo " -> Processing ${PACKAGE}"

  if [ "${SERVICES_OBJECT}" == "null" ]; then
    echo "    No services defined for ${PACKAGE}"
  else
    SERVICES=$(jq 'keys[]' <<< ${SERVICES_OBJECT})
    BASE_PATHS=($(jq '.[]' <<< ${SERVICES_OBJECT}))
    SERVICES_ARRAY=(${SERVICES})
    SERVICES_LENGTH=${#SERVICES_ARRAY[@]}
    if [ ${SERVICES_LENGTH} -eq 0 ]; then
      echo "    No services defined for ${PACKAGE}"
    else
      sed ${SED_OPTS} "s|.*ADD IMPORTS HERE.*|  gw${COUNT} \"${PROJECT_PATH}/stubs/${FOLDER}\""'\
&|' "${DESTINATION_PATH}/grpc-gateway.go"
    fi

    COUNT2=0
    for SERVICE in ${SERVICES}
    do
      ENDPOINT="Register"$(sed -e 's|"||g' <<< ${SERVICE})"HandlerFromEndpoint"
      echo "    Adding ${SERVICE}"
      PARAMETERS="${BACKEND}, ${BASE_PATHS[COUNT2]}, gw${COUNT}.${ENDPOINT}"
      sed ${SED_OPTS} -e "s|.*ADD ENDPOINTS HERE.*|  loadEndpoint(ctx, serverMux, ${PARAMETERS})"'\
&|' "${DESTINATION_PATH}/grpc-gateway.go"
      COUNT2=$((COUNT2+1))
    done
  fi

  COUNT=$((COUNT+1))
done

echo "CONFIGURING... grpc-gateway.go"
LISTEN=$(cat ${CONFIG_FILE} | jq '.gateway | .listen')
sed ${SED_OPTS} -e "s|\"LISTEN\"|${LISTEN}|" "${DESTINATION_PATH}/grpc-gateway.go"

echo "FIXING PATHS... in auto generated go files"
PACKAGES=$(find ${PROTOS_PATH} -type f -name "*.proto" -print | xargs grep -E "package( )+[^=\"]*;" -ho | uniq | sed 's/;/ /g')
for PACKAGE in ${PACKAGES}
do
  if [[ $PACKAGE != package* ]] && [[ $PACKAGE != google* ]] ; then
    find ${STUBS_PATH} -type f -name "*.go" -print0 | xargs -0 sed ${SED_OPTS} -e "s|\"${PACKAGE}\"|\"${PROJECT_PATH}/stubs/${PACKAGE}\"|g"
  fi
done
