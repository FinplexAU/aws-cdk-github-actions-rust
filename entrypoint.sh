#!/bin/bash

set -u

function parseInputs(){
	# Required inputs
	if [ "${INPUT_CDK_SUBCOMMAND}" == "" ]; then
		echo "Input cdk_subcommand cannot be empty"
		exit 1
	fi
}

function installTypescript(){
	npm install typescript
}

function installAwsCdk(){
	echo "Install aws-cdk ${INPUT_CDK_VERSION}"
	if [ "${INPUT_CDK_VERSION}" == "latest" ]; then
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			npm install -g aws-cdk
		else
			npm install -g aws-cdk >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-cdk ${INPUT_CDK_VERSION}"
		else
			echo "Successful install aws-cdk ${INPUT_CDK_VERSION}"
		fi
	else
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			npm install -g aws-cdk@${INPUT_CDK_VERSION}
		else
			npm install -g aws-cdk@${INPUT_CDK_VERSION} >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-cdk ${INPUT_CDK_VERSION}"
		else
			echo "Successful install aws-cdk ${INPUT_CDK_VERSION}"
		fi
	fi
}

function installPipRequirements(){
	if [ -e "requirements.txt" ]; then
		echo "Install requirements.txt"
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			pip install -r requirements.txt
		else
			pip install -r requirements.txt >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install requirements.txt"
		else
			echo "Successful install requirements.txt"
		fi
	fi
}

function runCdk(){
	echo "Run cdk ${INPUT_CDK_SUBCOMMAND} ${*} \"${INPUT_CDK_STACK}\""
	set -o pipefail
	cdk ${INPUT_CDK_SUBCOMMAND} ${*} "${INPUT_CDK_STACK}" 2>&1 | tee output.log
	exitCode=${?}
	set +o pipefail
	echo "status_code=${exitCode}" >> $GITHUB_OUTPUT
	output=$(cat output.log)

	commentStatus="Failed"
	if [ "${exitCode}" == "0" ]; then
		commentStatus="Success"
	elif [ "${exitCode}" != "0" ]; then
		echo "CDK subcommand ${INPUT_CDK_SUBCOMMAND} for stack ${INPUT_CDK_STACK} has failed. See above console output for more details."
		exit 1
	fi

	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${INPUT_ACTIONS_COMMENT}" == "true" ]; then
		commentWrapper="#### \`cdk ${INPUT_CDK_SUBCOMMAND}\` ${commentStatus}
<details><summary>Show Output</summary>

\`\`\`
${output}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${INPUT_WORKING_DIR}\`*"

		payload=$(echo "${commentWrapper}" | jq -R --slurp '{body: .}')
		commentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)

		echo "${payload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${commentsURL}" > /dev/null
	fi
}

function rustStuff(){
	export ZIG_VERSION=0.11.0
	apkArch=$(apk --print-arch) && curl -L https://ziglang.org/download/$ZIG_VERSION/zig-linux-$apkArch-$ZIG_VERSION.tar.xz | tar -J -x -C /usr/local \
	   && ln -s /usr/local/zig-linux-$apkArch-$ZIG_VERSION/zig /usr/local/bin/zig ;
	
	curl https://sh.rustup.rs -sSf | sh -s -- --profile minimal -y
	source "$HOME/.cargo/env"
	rustup default stable
	curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
	cargo binstall cargo-lambda -y
 	cargo binstall sccache --locked -y

   	# sccache setup
    	export SCCACHE_GHA_ENABLED=on
     	export RUSTC_WRAPPER=$(which sccache)
      	echo $RUSTC_WRAPPER
}

function main(){
	parseInputs
	cd ${GITHUB_WORKSPACE}/${INPUT_WORKING_DIR}
	installTypescript
	installAwsCdk
	installPipRequirements
 	rustStuff
 	sccache --show-stats
	runCdk ${INPUT_CDK_ARGS}
 	sccache --show-stats
}

main
