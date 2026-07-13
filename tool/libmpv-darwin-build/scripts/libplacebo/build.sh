#!/bin/sh

set -e # exit immediately if a command exits with a non-zero status
set -u # treat unset variables as an error

cd ${SRC_DIR}

rm -rf ./3rdparty
mkdir -p ./3rdparty

tar -xzvf "${DOWNLOADS_DIR}/fast_float-5.2.0.tar.gz" -C ./3rdparty/
mv ./3rdparty/fast_float-5.2.0 ./3rdparty/fast_float

tar -xzvf "${DOWNLOADS_DIR}/glad-2.0.4.tar.gz" -C ./3rdparty/
mv ./3rdparty/glad-2.0.4 ./3rdparty/glad

tar -xzvf "${DOWNLOADS_DIR}/jinja-3.1.2.tar.gz" -C ./3rdparty/
mv ./3rdparty/jinja-3.1.2 ./3rdparty/jinja

tar -xzvf "${DOWNLOADS_DIR}/markupsafe-2.1.2.tar.gz" -C ./3rdparty/
mv ./3rdparty/markupsafe-2.1.2 ./3rdparty/markupsafe

tar -xzvf "${DOWNLOADS_DIR}/Vulkan-Headers-1.3.243.tar.gz" -C ./3rdparty/
mv ./3rdparty/Vulkan-Headers-1.3.243 ./3rdparty/Vulkan-Headers

# Python 3.14 returns an ElementTree from ET.parse; libplacebo 7.349.0 expects
# the root Element at this call site.
sed -i '' 's/VkXML(ET.parse(xmlfile))/VkXML(ET.parse(xmlfile).getroot())/' src/vulkan/utils_gen.py

meson setup build \
    --cross-file ${PROJECT_DIR}/cross-files/${OS}-${ARCH}.ini \
    --prefix="${OUTPUT_DIR}" \
    -Ddemos=false \
    -Dtests=false

meson compile -C build
meson install -C build
