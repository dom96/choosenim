#! /bin/bash

# Use common Travis script - https://github.com/genotrance/nim-travis
curl https://raw.githubusercontent.com/genotrance/nim-travis/master/travis.sh -LsSf -o travis.sh
source travis.sh

# Skip building autotagged version
export COMMIT_TAG=`git tag --points-at HEAD | head -n 1`
export CURRENT_BRANCH="${TRAVIS_BRANCH}"
echo "Commit tag: ${COMMIT_TAG}"
echo "Current branch: ${CURRENT_BRANCH}"
if [[ "${COMMIT_TAG}" =~ ^v[0-9.]+-[0-9]+$ ]]; then
  echo "Skipping build since autotagged version"
else
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

  if [[ "$OSNAME" == "linux" ]]; then
    # musl-gcc static build for Linux
    export CC=musl-gcc # for nimterop
    export FLAGS="--gcc.exe:musl-gcc --gcc.linkerexe:musl-gcc --passL:-static"
  elif [[ "$OSNAME" == "windows" ]]; then
    # Static build on Windows
    export FLAGS="--passL:-static"
  fi

  # Build release version
  nimble install -y -d
  nim c -d:release ${FLAGS} src/choosenimpkg/proxyexe
  nim c -d:release --outdir:bin -d:skipBuild ${FLAGS} src/choosenim
  strip "bin/choosenim${EXT}"

  # Set version and tag info
  export CHOOSENIM_VERSION="$(./bin/choosenim --version | cut -f2,2 -d' ' | sed 's/v//')"
  echo "Version: v${CHOOSENIM_VERSION}"
  if [[ -z "${COMMIT_TAG}" ]]; then
    # Create tag with date, not an official tagged release
    export VERSION_TAG="${CHOOSENIM_VERSION}-$(date +'%Y%m%d')"
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
    echo "Tag does not match choosenim version"
    echo "  Commit tag: ${COMMIT_TAG}"
    echo "  Version: v${CHOOSENIM_VERSION}"
    echo "  Current branch: ${CURRENT_BRANCH}"
    travis_terminate 1
  fi
  echo "Travis tag: ${TRAVIS_TAG}"
  echo "Prerelease: ${PRERELEASE}"
  echo "Flags: ${FLAGS}"
  export FILENAME="bin/choosenim-${VERSION_TAG}_${OSNAME}_${TRAVIS_CPU_ARCH}"
  echo "Filename: ${FILENAME}"

  # Run tests
  nimble test -d:skipBuild
  mv "bin/choosenim${EXT}" "${FILENAME}_debug${EXT}"

  # Build debug version
  nim c -g ${FLAGS} src/choosenimpkg/proxyexe
  nim c -g --outdir:bin -d:skipBuild ${FLAGS} src/choosenim
  ./bin/choosenim${EXT} -v
  mv "bin/choosenim${EXT}" "${FILENAME}${EXT}"
fi
