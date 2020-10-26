#! /bin/bash

# Use common Travis script - https://github.com/genotrance/nim-travis
curl https://raw.githubusercontent.com/genotrance/nim-travis/master/travis.sh -LsSf -o travis.sh
source travis.sh

# Skip building autotagged version
export COMMIT_TAG=`git tag --points-at HEAD | head -n 1`
export COMMIT_HASH=`git rev-parse --short HEAD`
export CURRENT_BRANCH="${TRAVIS_BRANCH}"
echo "Commit tag: ${COMMIT_TAG}"
echo "Commit hash: ${COMMIT_HASH}"
echo "Current branch: ${CURRENT_BRANCH}"

# Environment vars
if [[ "$TRAVIS_OS_NAME" == "windows" ]]; then
  export EXT=".exe"
else
  export EXT=""
fi

if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  export OSNAME="macosx"
else
  export OSNAME="$TRAVIS_OS_NAME"
fi

# Build release version
nimble build -y -d:release -d:staticBuild

# Set version and tag info
export CHOOSENIM_VERSION="$(./bin/choosenim --version | cut -f2,2 -d' ' | sed 's/v//')"
echo "Version: v${CHOOSENIM_VERSION}"
if [[ -z "${COMMIT_TAG}" ]]; then
  # Create tag with date and hash, not an official tagged release
  export VERSION_TAG="${CHOOSENIM_VERSION}-$(date +'%Y%m%d')-${COMMIT_HASH}"
  if [[ "${CURRENT_BRANCH}" == "master" ]]; then
    # Deploy only on main branch
    export TRAVIS_TAG="v${VERSION_TAG}"
    export PRERELEASE=true
  fi
elif [[ "${COMMIT_TAG}" == "v${CHOOSENIM_VERSION}" ]]; then
  # Official tagged release
  export VERSION_TAG="${CHOOSENIM_VERSION}"
  export TRAVIS_TAG="${COMMIT_TAG}"
else
  # Other tag, mostly autotagged rebuild
  export VERSION_TAG="${COMMIT_TAG:1}"
  export TRAVIS_TAG="${COMMIT_TAG}"
  export PRERELEASE=true
fi
echo "Travis tag: ${TRAVIS_TAG}"
echo "Prerelease: ${PRERELEASE}"
export FILENAME="bin/choosenim-${VERSION_TAG}_${OSNAME}_${TRAVIS_CPU_ARCH}"
echo "Filename: ${FILENAME}"

# Run tests
nimble test -d:release -d:staticBuild
strip "bin/choosenim${EXT}"
mv "bin/choosenim${EXT}" "${FILENAME}${EXT}"

# Build debug version
nimble build -g -d:staticBuild
./bin/choosenim${EXT} -v
mv "bin/choosenim${EXT}" "${FILENAME}_debug${EXT}"
