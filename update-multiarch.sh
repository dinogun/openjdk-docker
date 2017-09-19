#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -eo pipefail

# Dockerfiles to be generated
version="9"
package="jdk slim"
arches="ppc64le s390x x86_64"
jvm="hotspot openj9"
osver="ubuntu alpine"

# sha256sum for the various versions, packages and arches
# Version 8 sums [DO NO EDIT THIS LINE]
declare -A jre_8_sums=(
	[version]="1.8.0_sr5"
	[i386]="973fd6f9c4a0f5fd4972b8bfa484d83360c3817cf9597346faa189ab63be074f"
	[ppc64le]="2886890c98cde880ff4ffe10108c10e13df6e5b90ca19d924498b44a4aca0e2a"
	[s390]="eeee4ccf83c0a959e72e1da4a758f169614bbcc641ff7c65ab2530758c6629ca"
	[s390x]="b0b39f01ace528ba7f6cd7bb59a5311cc989afc8774eefd2e877c8f03a27380d"
	[x86_64]="8721ed58195f90bcae6341033471322260dd4be21615c4e36cda9bb0eab24ca5"
)

declare -A jdk_8_sums=(
	[version]="1.8.0_sr5"
	[i386]="b45066ab6ae61b9a7b78b8828dc6f0dcd82ead18b120107c8f523c314592a1a8"
	[ppc64le]="52f54e1a4911f3a2123ea3e034818a1e8b2e707455ffb7dd9b104b6c5b4c38a6"
	[s390]="6e5ebc6791a16e62be541c28a788884ac91f4a6b8441f2eabc04ebb3dd8278b5"
	[s390x]="f2aec41f74441a829e5bbbc62f14dc8dd85d8a256c2d6e46ec4e8c071f3b23ed"
	[x86_64]="e0154e19d283b0257598cd62543c92f886cd0e33ce570750d80c92b1c27b532e"
)

declare -A sfj_8_sums=(
	[version]="1.8.0_sr5"
	[i386]="83c6c959a18f92c5fab9c0d70bc698e1aacd90e4f9aa1f41f9a2a78a0d31ec99"
	[ppc64le]="910f1f4079793f497ada5c31c3261229da403a1534330840a6af8c40ab1d8f01"
	[s390]="a274ff213f25ffefcd3aff51bbf9f8dd8c2d19b29e344fb6146f8b27beaf2748"
	[s390x]="a6c4fc3822305d80db4fe0034b5a492c0e6230da1f6e8850b9d0837820a56d7d"
	[x86_64]="2e2708187657c91d82e3641afd844b283c312ba680234d70e4a4a23316282efe"
)

# Version 9 sums [DO NO EDIT THIS LINE]
declare -A jdk_9_sums=(
	[version]="1.9.0_ea2"
	[i386]="5add39cc5ca56b97cf8ce71b9e1a15d19d36864aaed1e0296f50355ba3f34bd5"
	[ppc64le]="3c0dda9f449a667d12fe5f59a1ec059a90a9dc483fd35eef5ff53dd8b096cdf5"
	[s390]="8d06af57d8236839f5c403c12dcf4c89e22dd91716a4d26b85c8d92f6d1e2e8b"
	[s390x]="6e823afa1df83e364381f827f4244bfe29b0ddd58ef0203eb60df9b8c0d123af"
	[x86_64]="0fe3712b54a93695cf4948d9ae171bf5cef038c0e41b364b4e9eb7cb80a60688"
)

# Generate the common license and copyright header
print_legal() {
	cat > $1 <<-EOI
	# ------------------------------------------------------------------------------
	#               NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
	#
	#                       PLEASE DO NOT EDIT IT DIRECTLY.
	# ------------------------------------------------------------------------------
	#
	# Licensed under the Apache License, Version 2.0 (the "License");
	# you may not use this file except in compliance with the License.
	# You may obtain a copy of the License at
	#
	#      http://www.apache.org/licenses/LICENSE-2.0
	#
	# Unless required by applicable law or agreed to in writing, software
	# distributed under the License is distributed on an "AS IS" BASIS,
	# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	# See the License for the specific language governing permissions and
	# limitations under the License.
	#

	EOI
}

# Print the supported Ubuntu OS
print_ubuntu_os() {
	cat >> $1 <<-EOI
	FROM ubuntu:16.04

	EOI
}

# Print the supported Alpine OS
print_alpine_os() {
	cat >> $1 <<-EOI
	FROM alpine:3.6

	EOI
}

# Print the maintainer
print_maint() {
	cat >> $1 <<-EOI
	MAINTAINER Dinakar Guniguntala <dinakar.g@in.ibm.com> (@dinogun)
	EOI
}

# Select the ubuntu OS packages
print_ubuntu_pkg() {
	cat >> $1 <<'EOI'

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*
EOI
}

# Select the alpine OS packages.
# Install GNU glibc as J9 needs it, install libgcc_s.so from gcc-libs.tar.xz (archlinux)
print_alpine_pkg() {
	cat >> $1 <<'EOI'

RUN apk --update add --no-cache ca-certificates curl openssl binutils xz \
    && GLIBC_VER="2.25-r0" \
    && ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
    && curl -Ls ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/${GLIBC_VER}.apk \
    && apk add --allow-untrusted /tmp/${GLIBC_VER}.apk \
    && curl -Ls https://www.archlinux.org/packages/core/x86_64/gcc-libs/download > /tmp/gcc-libs.tar.xz \
    && mkdir /tmp/gcc \
    && tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc \
    && mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib \
    && strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* \
    && apk del curl binutils \
    && rm -rf /tmp/${GLIBC_VER}.apk /tmp/gcc /tmp/gcc-libs.tar.xz /var/cache/apk/*
EOI
}

# Print the Java version that is being installed here
print_env() {
	srcpkg=$2
	shasums="${srcpkg}"_"${ver}"_sums
	jverinfo=${shasums}[version]
	eval jver=\${$jverinfo}

	cat >> $1 <<-EOI

ENV JAVA_VERSION ${jver}

EOI
}

# OS independent portion (Works for both Alpine and Ubuntu)
# For Java 9 we use jlink to derive the JRE and the SFJ images.
print_java_install() {
	cat >> $1 <<-EOI
       amd64|x86_64) \\
         JAVA_URL=\$(cat /tmp/latest.json | grep "browser_download_url" | grep x64 | grep -v "sha" | awk -F'"' '{ print \$4 }'); \\
         ;; \\
       ppc64el|ppc64le) \\
         JAVA_URL=\$(cat /tmp/latest.json | grep "browser_download_url" | grep ppc64le | grep -v "sha" | awk -F'"' '{ print \$4 }'); \\
         ;; \\
       s390x) \\
         JAVA_URL=\$(cat /tmp/latest.json | grep "browser_download_url" | grep s390x | grep -v "sha" | awk -F'"' '{ print \$4 }'); \\
         ;; \\
       *) \\
         echo "Unsupported arch: \${ARCH}"; \\
         exit 1; \\
         ;; \\
    esac; \\
EOI
	cat >> $1 <<'EOI'
    wget -q -O /tmp/openjdk.tar.gz ${JAVA_URL}; \
    mkdir -p /opt/java/openjdk; \
    cd /opt/java/openjdk; \
	tar -xvf /tmp/openjdk.tar.gz; \
    rm -f /tmp/openjdk.tar.gz;
EOI

}

# Print the main RUN command that installs Java on ubuntu.
print_ubuntu_java_install() {
	srcpkg=$2
	dstpkg=$3
	if [ "$vm" == "hotspot" ]; then
		release_dir="openjdk9-releases";
	elif [ "$vm" == "openj9" ]; then
		release_dir="openjdk9-openj9-releases";
	fi
	cat >> $1 <<-EOI
RUN set -eux; \\
    JSON_URL='https://raw.githubusercontent.com/AdoptOpenJDK/${release_dir}/master/latest_release.json'; \\
    wget -q -O /tmp/latest.json \${JSON_URL}; \\
    ARCH="\$(dpkg --print-architecture)"; \\
    case "\${ARCH}" in \\
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

# Print the main RUN command that installs Java on alpine.
print_alpine_java_install() {
	srcpkg=$2
	dstpkg=$3
	cat >> $1 <<'EOI'
RUN set -eux; \
    JSON_URL="https://raw.githubusercontent.com/AdoptOpenJDK/openjdk9-openj9-releases/master/latest_release.json"; \
    wget -q -O /tmp/latest.json ${JSON_URL}; \
    export RELEASE=\$(cat /tmp/latest.json | grep "tag_name" | awk -F'"' '{ print \$4 }'); \
    ARCH="$(apk --print-arch)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

print_java_env() {
	JPATH="/opt/java/openjdk/$RELEASE/bin"
	TPATH="PATH=${JPATH}:\$PATH"

	cat >> $1 <<-EOI

ENV ${TPATH}
EOI
}

print_exclude_file() {
	srcpkg=$2
	dstpkg=$3
	if [ "${ver}" == "9" -a "${dstpkg}" == "sfj" ]; then
		cp sfj-exclude.txt `dirname ${file}`
		cat >> $1 <<-EOI
COPY sfj-exclude.txt /tmp

EOI
	fi
}

generate_java() {
	if [ "${ver}" == "9" ]; then
		srcpkg="jdk";
	else
		srcpkg=${pack};
	fi
	dstpkg=${pack};
	print_env ${file} ${srcpkg};
	print_exclude_file ${file} ${srcpkg} ${dstpkg};
if [ "${os}" == "ubuntu" ]; then
		print_ubuntu_java_install ${file} ${srcpkg} ${dstpkg};
elif [ "${os}" == "alpine" ]; then
		print_alpine_java_install ${file} ${srcpkg} ${dstpkg};
fi
	print_java_env ${file};
}

generate_ubuntu() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_ubuntu_os ${file};
	print_maint ${file};
	print_ubuntu_pkg ${file};
	generate_java ${file};
	echo "done"
}

generate_alpine() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_alpine_os ${file};
	print_maint ${file};
	print_alpine_pkg ${file};
	generate_java ${file};
	echo "done"
}

# Iterate through all the Java versions for each of the supported packages,
# architectures and supported Operating Systems.
for ver in ${version}
do
	for pack in ${package}
	do
		for os in ${osver}
		do
			for vm in ${jvm}
			do
				file=${ver}/${pack}/${os}/Dockerfile.${vm}
				# Ubuntu is supported for everything
				if [ "${os}" == "ubuntu" ]; then
					generate_ubuntu ${file}
				elif [ "${os}" == "alpine" ]; then
					generate_alpine ${file}
				fi
			done
		done
	done
done
