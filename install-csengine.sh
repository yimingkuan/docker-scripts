# Ubuntu, CentOS, Red Hat support only, so far. SUSE is untested

set -e

version="1.11"
apt_url="https://packages.docker.com/${version}/apt"
yum_url="https://packages.docker.com/${version}/yum"
gpg_fingerprint="0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
key_server="https://sks-keyservers.net/pks/lookup?op=get&search="
#key_server="ha.pool.sks-keyservers.net"

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

echo_docker_as_nonroot() {
	if command_exists docker && [ -e /var/run/docker.sock ]; then
		(
			set -x
			$sh_c 'docker version'
		) || true
	fi
	your_user=your-user
	[ "$user" != 'root' ] && your_user="$user"
	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	cat <<-EOF

	If you would like to use Docker as a non-root user, you should now consider
	adding your user to the "docker" group with something like:

		sudo usermod -aG docker $your_user

	Remember that you will have to log out and back in for this to take effect!

	EOF
}

rpm_import_repository_key() {
	local key=$1; shift
	local tmpdir=$(mktemp -d)
	chmod 600 "$tmpdir"
	gpg --homedir "$tmpdir" --keyserver "$key_server" --recv-keys "$key"
	gpg --homedir "$tmpdir" -k "$key" >/dev/null
	gpg --homedir "$tmpdir" --export --armor "$key" > "$tmpdir"/repo.key
	rpm --import "$tmpdir"/repo.key
	rm -rf "$tmpdir"
}

do_install() {
	case "$(uname -m)" in
		*64)
			;;
		*)
			cat >&2 <<-'EOF'
			Error: you are not using a 64bit platform.
			Docker currently only supports 64bit platforms.
			EOF
			exit 1
			;;
	esac

	if command_exists docker; then
		version="$(docker -v | awk -F '[ ,]+' '{ print $3 }')"
		MAJOR_W=1
		MINOR_W=10

		semverParse $version

		shouldWarn=0
		if [ $major -lt $MAJOR_W ]; then
			shouldWarn=1
		fi

		if [ $major -le $MAJOR_W ] && [ $minor -lt $MINOR_W ]; then
			shouldWarn=1
		fi

		cat >&2 <<-'EOF'
			Warning: the "docker" command appears to already exist on this system.

			If you already have Docker installed, this script can cause trouble, which is
			why we're displaying this warning and provide the opportunity to cancel the
			installation.

			If you installed the current Docker package using this script and are using it
		EOF

		if [ $shouldWarn -eq 1 ]; then
			cat >&2 <<-'EOF'
			again to update Docker, we urge you to migrate your image store before upgrading
			to v1.10+.

			You can find instructions for this here:
			https://github.com/docker/docker/wiki/Engine-v1.10.0-content-addressability-migration
			EOF
		else
			cat >&2 <<-'EOF'
			again to update Docker, you can safely ignore this message.
			EOF
		fi

		cat >&2 <<-'EOF'

			You may press Ctrl+C now to abort this script.
		EOF
		( set -x; sleep 20 )
	fi

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	curl=''
	if command_exists curl; then
		curl='curl -sSL'
	elif command_exists wget; then
		curl='wget -qO-'
	elif command_exists busybox && busybox --list-modules | grep -q wget; then
		curl='busybox wget -qO-'
	fi

	lsb_dist=''
	dist_version=''
	if command_exists lsb_release; then
		lsb_dist="$(lsb_release -si)"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
		lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
		lsb_dist='debian'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
		lsb_dist='fedora'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/oracle-release ]; then
		lsb_dist='oracleserver'
	fi
	if [ -z "$lsb_dist" ]; then
		if [ -r /etc/centos-release ] || [ -r /etc/redhat-release ]; then
			lsb_dist='centos'
		fi
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
	
	case "$lsb_dist" in
	
		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;
	
		debian)
			dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
			case "$dist_version" in
				8)
					dist_version="jessie"
				;;
				7)
					dist_version="wheezy"
				;;
			esac
		;;
	
		centos)
			dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
		;;
	
		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;
	esac
	
	curl=''
		if command_exists curl; then
			curl='curl -sSL'
		elif command_exists wget; then
			curl='wget -qO-'
		elif command_exists busybox && busybox --list-modules | grep -q wget; then
			curl='busybox wget -qO-'
		fi
	
	case "$lsb_dist" in
		
		'suse linux'|sle[sd])
			$sh_c 'zypper ref'
			$sh_c 'zypper ar -t YUM ${yum_url}/repo/main/opensuse/12.3 docker-${version}'
			$sh_c 'rpm --import "${key_server}${gpg_fingerprint}"'
			$sh_c 'zypper install docker-engine'
			echo_docker_as_nonroot
			exit 0
			;;
	
		ubuntu|debian)
			export DEBIAN_FRONTEND=noninteractive
	
			did_apt_get_update=
			apt_get_update() {
				if [ -z "$did_apt_get_update" ]; then
					( set -x; $sh_c 'sleep 3; apt-get update' )
					did_apt_get_update=1
				fi
			}
	
			# aufs is preferred over devicemapper; try to ensure the driver is available.
			if ! grep -q aufs /proc/filesystems && ! $sh_c 'modprobe aufs'; then
				if uname -r | grep -q -- '-generic' && dpkg -l 'linux-image-*-generic' | grep -qE '^ii|^hi' 2>/dev/null; then
					kern_extras="linux-image-extra-$(uname -r) linux-image-extra-virtual"
	
					apt_get_update
					( set -x; $sh_c 'sleep 3; apt-get install -y -q '"$kern_extras" ) || true
	
					if ! grep -q aufs /proc/filesystems && ! $sh_c 'modprobe aufs'; then
						echo >&2 'Warning: tried to install '"$kern_extras"' (for AUFS)'
						echo >&2 ' but we still have no AUFS.	Docker may not work. Proceeding anyways!'
						( set -x; sleep 10 )
					fi
				else
					echo >&2 'Warning: current kernel is not supported by the linux-image-extra-virtual'
					echo >&2 ' package.	We have no AUFS support.	Consider installing the packages'
					echo >&2 ' linux-image-virtual kernel and linux-image-extra-virtual for AUFS support.'
					( set -x; sleep 10 )
				fi
			fi
	
			# install apparmor utils if they're missing and apparmor is enabled in the kernel
			# otherwise Docker will fail to start
			if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = 'Y' ]; then
				if command -v apparmor_parser >/dev/null 2>&1; then
					echo 'apparmor is enabled in the kernel and apparmor utils were already installed'
				else
					echo 'apparmor is enabled in the kernel, but apparmor_parser missing'
					apt_get_update
					( set -x; $sh_c 'sleep 3; apt-get install -y -q apparmor' )
				fi
			fi
	
			if [ ! -e /usr/lib/apt/methods/https ]; then
				apt_get_update
				( set -x; $sh_c 'sleep 3; apt-get install -y -q apt-transport-https ca-certificates' )
			fi
			if [ -z "$curl" ]; then
				apt_get_update
				( set -x; $sh_c 'sleep 3; apt-get install -y -q curl ca-certificates' )
				curl='curl -sSL'
			fi
			(
			set -x
			$sh_c '$curl "${key_server}${gpg_fingerprint}" | apt-key add --import'
			#$sh_c "apt-key adv --keyserver hkp://${key_server}:80 --recv-keys ${gpg_fingerprint}"
			#$sh_c "apt-key adv -k ${gpg_fingerprint} >/dev/null"
			$sh_c 'mkdir -p /etc/apt/sources.list.d'
			$sh_c 'echo deb ${apt_url}/repo ${lsb_dist}-${dist_version} main > /etc/apt/sources.list.d/docker.list'
			$sh_c 'sleep 3; apt-get update; apt-get install -y -q docker-engine'
			)
			echo_docker_as_nonroot
			exit 0
			;;
	
		centos)
			echo ${key_server}
			echo ${gpg_fingerprint}
			echo ${key_server}${gpg_fingerprint}
			$sh_c "rpm --import '${key_server}${gpg_fingerprint}'"
			$sh_c 'yum -y -q install yum-utils'
			$sh_c "yum-config-manager --add-repo ${yum_url}/repo/main/${lsb_dist}/${dist_version}"
			#$sh_c "cat >/etc/yum.repos.d/docker-main.repo" <<-EOF
			#[docker-main-repo]
			#name=docker main repository - ${lsb_dist}/${dist_version}
			#baseurl=${yum_url}/repo/main/${lsb_dist}/${dist_version}
			#enabled=1
			#gpgcheck=1
			#gpgkey=${yum_url}/gpg
			#EOF
			set -x
			$sh_c 'sleep 3; yum -y -q install docker-engine'
			echo_docker_as_nonroot
			exit 0
			;;
	esac

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-'EOF'", spaces are kept in the output
	cat >&2 <<-'EOF'

		Either your platform is not easily detectable, is not supported by this
		installer script (yet - PRs welcome! [hack/install.sh]), or does not yet have
		a package for Docker.	Please visit the following URL for more detailed
		installation instructions:

			https://docs.docker.com/engine/installation/

	EOF
	exit 1
}

do_install


