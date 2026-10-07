// node:sea — Single Executable Application stubs (Wave 18)
// We are never running as a SEA binary.

function _notInSea(name) {
    var err = new Error(
        "Cannot " + name + " because the current process is not a Single Executable Application"
    );
    err.code = "ERR_NOT_IN_SINGLE_EXECUTABLE_APPLICATION";
    return err;
}

function isSea() {
    return false;
}

function getAsset() {
    throw _notInSea("getAsset");
}

function getAssetAsBlob() {
    throw _notInSea("getAssetAsBlob");
}

function getRawAsset() {
    throw _notInSea("getRawAsset");
}

function getAssetKeys() {
    throw _notInSea("getAssetKeys");
}

module.exports = {
    isSea: isSea,
    getAsset: getAsset,
    getAssetAsBlob: getAssetAsBlob,
    getRawAsset: getRawAsset,
    getAssetKeys: getAssetKeys
};
