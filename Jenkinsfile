pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'TEST_SUITE',
            defaultValue: 'Test Suites/Smoke',
            description: 'Katalon test suite path'
        )
        string(
            name: 'KATALON_PROJECT_PATH',
            defaultValue: '/katalon/project',
            description: 'Path to the Katalon project inside the ECS container'
        )
        string(
            name: 'SUBNET_IDS',
            defaultValue: 'subnet-0968b2a4486c2c297',
            description: 'Comma-separated subnet IDs for Fargate task networking'
        )
        string(
            name: 'SECURITY_GROUP_IDS',
            defaultValue: 'sg-014254f1dc8168a1a',
            description: 'Comma-separated security group IDs for the Fargate task'
        )
        choice(
            name: 'ASSIGN_PUBLIC_IP',
            choices: ['DISABLED', 'ENABLED'],
            description: 'Usually DISABLED for private subnets'
        )
    }

    environment {
        AWS_REGION          = 'us-west-2'
        ECS_CLUSTER         = 'katalon-testing-cluster'
        ECS_TASK_DEFINITION = 'katalon-runner'
        ECS_CONTAINER_NAME  = 'katalon-container'
        KATALON_ORG_ID      = '2333388'
        CW_LOG_GROUP        = '/ecs/katalon-tests'
    }

    stages {
        stage('Init') {
            steps {
                script {
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()

                    env.NORMALIZED_TEST_SUITE = params.TEST_SUITE?.trim()
                    if (!env.NORMALIZED_TEST_SUITE) {
                        env.NORMALIZED_TEST_SUITE = 'Test Suites/Smoke'
                    }
                    if (!env.NORMALIZED_TEST_SUITE.startsWith('Test Suites/')) {
                        env.NORMALIZED_TEST_SUITE =
                            "Test Suites/${env.NORMALIZED_TEST_SUITE}"
                    }

                    echo "BUILD_TIMESTAMP=${env.BUILD_TIMESTAMP}"
                    echo "TEST_SUITE=${env.NORMALIZED_TEST_SUITE}"
                    echo "KATALON_PROJECT_PATH=${params.KATALON_PROJECT_PATH}"
                    echo "SUBNET_IDS=${params.SUBNET_IDS}"
                    echo "SECURITY_GROUP_IDS=${params.SECURITY_GROUP_IDS}"
                    echo "ASSIGN_PUBLIC_IP=${params.ASSIGN_PUBLIC_IP}"
                }
            }
        }

        stage('Tool Check') {
            steps {
                sh '''
                    set -e
                    command -v aws >/dev/null 2>&1 || {
                      echo "ERROR: aws CLI not found on Jenkins agent"
                      exit 1
                    }
                    aws --version
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Run Katalon on ECS') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'katalon-api-key',
                        variable: 'KATALON_API_KEY'
                    )
                ]) {
                    script {
                        def subnetList = params.SUBNET_IDS
                            .split(',')
                            .collect { it.trim() }
                            .findAll { it }

                        def securityGroupList = params.SECURITY_GROUP_IDS
                            .split(',')
                            .collect { it.trim() }
                            .findAll { it }

                        if (subnetList.isEmpty()) {
                            error('SUBNET_IDS cannot be empty')
                        }
                        if (securityGroupList.isEmpty()) {
                            error('SECURITY_GROUP_IDS cannot be empty')
                        }

                        def cleanApiKey = env.KATALON_API_KEY?.trim()
                            ?.replaceFirst(/^apiKey=/, '')

                        def commandList = [
                            "-runMode=console",
                            "-projectPath=${params.KATALON_PROJECT_PATH}",
                            "-testSuitePath=${env.NORMALIZED_TEST_SUITE}",
                            "-browserType=Chrome",
                            "-apiKey=${cleanApiKey}",
                            "-orgID=${env.KATALON_ORG_ID}",
                            "-retry=0",
                            "-statusDelay=15",
                            "-buildLabel=jenkins-${env.BUILD_NUMBER}-${env.BUILD_TIMESTAMP}"
                        ]

                        def overridesMap = [
                            containerOverrides: [[
                                name   : env.ECS_CONTAINER_NAME,
                                command: commandList
                            ]]
                        ]

                        def networkConfigMap = [
                            awsvpcConfiguration: [
                                subnets       : subnetList,
                                securityGroups: securityGroupList,
                                assignPublicIp: params.ASSIGN_PUBLIC_IP
                            ]
                        ]

                        writeFile(
                            file: 'ecs-overrides.json',
                            text: groovy.json.JsonOutput.toJson(overridesMap)
                        )
                        writeFile(
                            file: 'ecs-network-config.json',
                            text: groovy.json.JsonOutput.toJson(networkConfigMap)
                        )

                        def taskArn = sh(
                            script: """
                                aws ecs run-task \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --task-definition '${env.ECS_TASK_DEFINITION}' \
                                  --launch-type FARGATE \
                                  --count 1 \
                                  --network-configuration file://ecs-network-config.json \
                                  --overrides file://ecs-overrides.json \
                                  --query 'tasks[0].taskArn' \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        if (!taskArn || taskArn == 'None' || taskArn == 'null') {
                            error('Failed to start ECS task: no taskArn returned')
                        }

                        env.ECS_TASK_ARN = taskArn
                        env.ECS_TASK_ID = taskArn.tokenize('/').last()

                        echo "Started ECS task: ${env.ECS_TASK_ARN}"

                        sh """
                            aws ecs wait tasks-stopped \
                              --region '${env.AWS_REGION}' \
                              --cluster '${env.ECS_CLUSTER}' \
                              --tasks '${env.ECS_TASK_ARN}'
                        """

                        def exitCode = sh(
                            script: """
                                aws ecs describe-tasks \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --tasks '${env.ECS_TASK_ARN}' \
                                  --query "tasks[0].containers[?name=='${env.ECS_CONTAINER_NAME}'].exitCode | [0]" \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        def stopReason = sh(
                            script: """
                                aws ecs describe-tasks \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --tasks '${env.ECS_TASK_ARN}' \
                                  --query "tasks[0].stoppedReason" \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        echo "Task stopped reason: ${stopReason}"
                        echo "Container exit code: ${exitCode}"

                        if (exitCode != '0') {
                            error(
                                "Katalon ECS task failed. " +
                                "taskArn=${env.ECS_TASK_ARN}, " +
                                "exitCode=${exitCode}, " +
                                "stoppedReason=${stopReason}"
                            )
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (env.ECS_TASK_ARN?.trim()) {
                    echo "Final ECS task ARN: ${env.ECS_TASK_ARN}"
                    echo "CloudWatch log group: ${env.CW_LOG_GROUP}"
                    echo "Look for log stream starting with: ecs/${env.ECS_CONTAINER_NAME}/${env.ECS_TASK_ID}"
                }
            }
            archiveArtifacts artifacts: 'ecs-overrides.json,ecs-network-config.json', allowEmptyArchive: true
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}