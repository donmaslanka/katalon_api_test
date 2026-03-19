pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'TEST_SUITE',
            defaultValue: 'Smoke',
            description: 'Katalon test suite name or path under Test Suites/'
        )
        string(
            name: 'TARGET_URL',
            defaultValue: 'https://example.com',
            description: 'Target website URL to test'
        )
        choice(
            name: 'BROWSER',
            choices: ['Chrome', 'Firefox', 'Edge'],
            description: 'Browser to use for testing'
        )
        booleanParam(
            name: 'WAIT_FOR_COMPLETION',
            defaultValue: true,
            description: 'Wait for ECS task to complete before finishing the build'
        )
    }

    environment {
        AWS_REGION        = 'us-west-2'
        ECS_CLUSTER       = credentials('ecs-cluster-name')
        TASK_DEFINITION   = credentials('ecs-task-definition')
        SUBNETS           = credentials('ecs-subnets')
        SECURITY_GROUP    = credentials('ecs-security-group')
        S3_RESULTS_BUCKET = credentials('s3-results-bucket')
        KATALON_ORG_ID    = '2333388'
        PROJECT_PATH      = '/katalon/project'
        CW_LOG_GROUP      = '/ecs/katalon-testing-dev-katalon'
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()

                    env.TASK_ARN = ''
                    env.TASK_ID = ''

                    echo "Test Configuration:"
                    echo "  Test Suite: ${params.TEST_SUITE}"
                    echo "  Target URL: ${params.TARGET_URL}"
                    echo "  Browser: ${params.BROWSER}"
                    echo "  Build ID: ${env.BUILD_TIMESTAMP}"
                    echo "  Region: ${env.AWS_REGION}"
                    echo "  Cluster: ${env.ECS_CLUSTER}"
                    echo "  Task Definition: ${env.TASK_DEFINITION}"
                }
            }
        }

        stage('Validate Agent Tooling') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    command -v aws >/dev/null 2>&1 || {
                      echo "ERROR: aws CLI is not installed on this Jenkins agent"
                      exit 1
                    }
                    aws --version
                '''
            }
        }

        stage('Start ECS Task') {
            steps {
                withCredentials([
                    string(credentialsId: 'katalon-api-key', variable: 'KATALON_API_KEY')
                ]) {
                    script {
                        def suitePath = params.TEST_SUITE.startsWith('Test Suites/')
                            ? params.TEST_SUITE
                            : "Test Suites/${params.TEST_SUITE}"

                        def overrides = [
                            containerOverrides: [[
                                name: 'katalon',
                                environment: [
                                    [name: 'TEST_SUITE', value: params.TEST_SUITE],
                                    [name: 'TARGET_URL', value: params.TARGET_URL],
                                    [name: 'BROWSER', value: params.BROWSER],
                                    [name: 'BUILD_ID', value: env.BUILD_TIMESTAMP],
                                    [name: 'JENKINS_BUILD_NUMBER', value: env.BUILD_NUMBER],
                                    [name: 'S3_BUCKET', value: env.S3_RESULTS_BUCKET]
                                ],
                                command: [
                                    'katalonc',
                                    "-projectPath=${env.PROJECT_PATH}",
                                    "-browserType=${params.BROWSER}",
                                    '-retry=0',
                                    '-statusDelay=15',
                                    "-testSuitePath=${suitePath}",
                                    "-apiKey=${KATALON_API_KEY}",
                                    "-orgID=${env.KATALON_ORG_ID}"
                                ]
                            ]]
                        ]

                        writeFile(
                            file: 'ecs-overrides.json',
                            text: groovy.json.JsonOutput.prettyPrint(
                                groovy.json.JsonOutput.toJson(overrides)
                            )
                        )

                        echo 'Starting Katalon test on ECS Fargate...'

                        env.TASK_ARN = sh(
                            script: '''#!/usr/bin/env bash
                                set -euo pipefail
                                aws ecs run-task \
                                  --region "$AWS_REGION" \
                                  --cluster "$ECS_CLUSTER" \
                                  --task-definition "$TASK_DEFINITION" \
                                  --launch-type FARGATE \
                                  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
                                  --overrides file://ecs-overrides.json \
                                  --query 'tasks[0].taskArn' \
                                  --output text
                            ''',
                            returnStdout: true
                        ).trim()

                        if (!env.TASK_ARN || env.TASK_ARN == 'None' || env.TASK_ARN == 'null') {
                            error('Failed to start ECS task')
                        }

                        env.TASK_ID = env.TASK_ARN.tokenize('/').last()

                        echo "ECS Task Started:"
                        echo "  Task ARN: ${env.TASK_ARN}"
                        echo "  Task ID: ${env.TASK_ID}"
                    }
                }
            }
        }

        stage('Monitor Task') {
            when {
                expression { params.WAIT_FOR_COMPLETION }
            }
            steps {
                script {
                    echo 'Monitoring ECS task execution...'

                    waitUntil(initialRecurrencePeriod: 10000) {
                        def taskStatus = sh(
                            script: '''#!/usr/bin/env bash
                                set -euo pipefail
                                aws ecs describe-tasks \
                                  --region "$AWS_REGION" \
                                  --cluster "$ECS_CLUSTER" \
                                  --tasks "$TASK_ARN" \
                                  --query 'tasks[0].lastStatus' \
                                  --output text
                            ''',
                            returnStdout: true
                        ).trim()

                        echo "Task Status: ${taskStatus}"
                        return taskStatus == 'STOPPED'
                    }
                }
            }
        }

        stage('Check Results') {
            when {
                expression { params.WAIT_FOR_COMPLETION }
            }
            steps {
                script {
                    def exitCode = sh(
                        script: '''#!/usr/bin/env bash
                            set -euo pipefail
                            aws ecs describe-tasks \
                              --region "$AWS_REGION" \
                              --cluster "$ECS_CLUSTER" \
                              --tasks "$TASK_ARN" \
                              --query 'tasks[0].containers[0].exitCode' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    def stopReason = sh(
                        script: '''#!/usr/bin/env bash
                            set -euo pipefail
                            aws ecs describe-tasks \
                              --region "$AWS_REGION" \
                              --cluster "$ECS_CLUSTER" \
                              --tasks "$TASK_ARN" \
                              --query 'tasks[0].stoppedReason' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "Task Exit Code: ${exitCode}"
                    echo "Stop Reason: ${stopReason}"

                    if (exitCode != '0') {
                        error("Katalon tests failed with exit code: ${exitCode}")
                    }
                }
            }
        }

        stage('Download Test Results') {
            when {
                expression { params.WAIT_FOR_COMPLETION }
            }
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    mkdir -p "$WORKSPACE/test-results"
                    aws s3 sync \
                      "s3://$S3_RESULTS_BUCKET/builds/$BUILD_NUMBER/" \
                      "$WORKSPACE/test-results/" || echo "No results found in S3"
                '''

                archiveArtifacts artifacts: 'test-results/**/*', allowEmptyArchive: true
            }
        }

        stage('View Logs') {
            steps {
                echo "CloudWatch Logs:"
                echo "  Log Group: ${env.CW_LOG_GROUP}"
                echo "  Task ID: ${env.TASK_ID}"
                echo ''
                echo 'View logs with:'
                echo "  aws logs tail ${env.CW_LOG_GROUP} --follow --region ${env.AWS_REGION}"
            }
        }
    }

    post {
        always {
            echo '═══════════════════════════════════════════════'
            echo 'Build Summary:'
            echo "  Build Number: ${env.BUILD_NUMBER}"
            echo "  Build Timestamp: ${env.BUILD_TIMESTAMP ?: 'n/a'}"
            echo "  Test Suite: ${params.TEST_SUITE}"
            echo "  Target URL: ${params.TARGET_URL}"
            echo "  Task ARN: ${env.TASK_ARN ?: 'n/a'}"
            echo "  Task ID: ${env.TASK_ID ?: 'n/a'}"
            echo '═══════════════════════════════════════════════'
        }
        success {
            echo '✓ Katalon tests completed successfully!'
        }
        failure {
            echo '✗ Katalon tests failed. Check ECS task status and CloudWatch logs.'
        }
    }
}
