def imageTag = ''

pipeline {
    agent any

    environment {
        DOCKER_BUILDKIT     = '1'
        BUILDKIT_PROGRESS   = 'plain'
        HARBOR_PROJECT      = 'sample-microservice'
    }

    parameters {
        choice(
            name: 'BUILD_TARGET',
            choices: ['all', 'adservice', 'cartservice', 'checkoutservice', 'currencyservice',
                      'emailservice', 'frontend', 'paymentservice', 'productcatalogservice',
                      'recommendationservice', 'shippingservice', 'shoppingassistantservice'],
            description: 'Select which service(s) to build'
        )
        booleanParam(name: 'PUSH_IMAGES',        defaultValue: true,                  description: 'Push Docker images to Harbor?')
        string(name: 'HARBOR_REGISTRY',          defaultValue: 'localhost',            description: 'Harbor registry URL (e.g., 192.168.1.100)')
        string(name: 'SONARQUBE_URL',            defaultValue: 'http://sonarqube:9000',description: 'SonarQube server URL')
    }

    stages {

        stage('Checkout') {
            steps {
                script {
                    checkout scm
                    echo "✓ Checked out — commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Prepare Image Tag') {
            steps {
                script {
                    def ts          = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def buildNumber = env.BUILD_NUMBER ?: currentBuild.number.toString()
                    imageTag = "${buildNumber}-${ts}"
                    echo "✓ Image tag: ${imageTag}"
                }
            }
        }

        stage('Validate Services') {
            steps {
                script {
                    echo '✓ Validating service Dockerfiles...'
                    getBuildServices().each { service ->
                        // Resolved here — on the checked-out workspace — before parallel nodes spin up
                        def path = resolveDockerfilePath(service)
                        echo "  ✓ ${service} → ${path}"
                    }
                }
            }
        }

        stage('Build & Analyze Services') {
            steps {
                script {
                    // Stash the whole source tree so every parallel node can unstash it
                    stash name: 'source', includes: 'src/**'

                    def parallelStages = [:]

                    getBuildServices().each { service ->
                        def svc = service   // capture for closure

                        parallelStages[svc] = {
                            node {
                                // Each new node starts with an empty workspace — restore the source
                                unstash 'source'

                                def dockerfilePath = resolveDockerfilePath(svc)
                                def buildContext   = (svc == 'cartservice') ? 'src/cartservice/src' : "src/${svc}"

                                stage("${svc}: SonarQube Scan") {
                                    try {
                                        dir("src/${svc}") {
                                            def scannerHome = tool 'Sonarqube'
                                            withSonarQubeEnv() {
                                                sh """
                                                    ${scannerHome}/bin/sonar-scanner \
                                                        -Dsonar.projectKey=${svc} \
                                                        -Dsonar.sources=.
                                                """
                                            }
                                        }
                                        echo "  ✓ ${svc} scan completed"
                                    } catch (e) {
                                        echo "  ⚠ ${svc} scan failed — ${e.message}"
                                    }
                                }

                                stage("${svc}: Build Docker Image") {
                                    sh """
                                        docker build \
                                            -f ${dockerfilePath} \
                                            -t ${params.HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${imageTag} \
                                            -t ${params.HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest \
                                            ${buildContext}
                                    """
                                    echo "  ✓ ${svc} image built"
                                }
                            }
                        }
                    }

                    parallel parallelStages
                }
            }
        }

        stage('Security Scan') {
            when { branch 'main' }
            steps {
                echo '✓ Security scan placeholder'
            }
        }

        stage('Push Docker Images') {
            when {
                expression { params.PUSH_IMAGES == true }
            }
            steps {
                script {
                    echo "✓ Pushing images (tag: ${imageTag})..."

                    sh '''
                        curl -sf -k https://${HARBOR_REGISTRY}/api/v2.0/health \
                            && echo "  ✓ Harbor reachable" \
                            || echo "  ⚠ Harbor may not be reachable"
                    '''

                    withCredentials([usernamePassword(
                            credentialsId: 'jenkin-cred',
                            usernameVariable: 'HARBOR_USER',
                            passwordVariable: 'HARBOR_PASS')]) {

                        sh 'echo $HARBOR_PASS | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}'

                        getBuildServices().each { svc ->
                            sh """
                                if docker image inspect ${params.HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${imageTag} >/dev/null 2>&1; then
                                    docker push ${params.HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${imageTag}
                                    docker push ${params.HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest
                                    echo "  ✓ ${svc} pushed"
                                else
                                    echo "  ⚠ Image not found for ${svc}, skipping push"
                                fi
                            """
                        }

                        sh 'docker logout || true'
                    }
                }
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                echo '✓ Deployment placeholder — configure your deploy steps here'
            }
        }
    }

    post {
        always  { sh 'docker logout || true' }
        success { echo '✓ Pipeline succeeded!' }
        failure { echo '✗ Pipeline failed!'   }
    }
}

// ==================== Helper Functions ====================

def getServiceList() {
    return ['adservice', 'cartservice', 'checkoutservice', 'currencyservice',
            'emailservice', 'frontend', 'paymentservice', 'productcatalogservice',
            'recommendationservice', 'shippingservice', 'shoppingassistantservice']
}

def getBuildServices() {
    return (params.BUILD_TARGET == 'all') ? getServiceList() : [params.BUILD_TARGET]
}

def resolveDockerfilePath(String service) {
    def serviceDir = "src/${service}"

    // Prefer a Dockerfile at the service root; fall back to any Dockerfile found recursively
    def path = sh(
        script: """
            # 1. Preferred locations checked in priority order
            for candidate in \
                "${serviceDir}/Dockerfile" \
                "${serviceDir}/src/Dockerfile" \
                "${serviceDir}/docker/Dockerfile" \
                "${serviceDir}/build/Dockerfile"; do
                [ -f "\$candidate" ] && echo "\$candidate" && exit 0
            done
            # 2. Recursive fallback — take the first result
            find "${serviceDir}" -name 'Dockerfile' -type f | sort | head -1
        """,
        returnStdout: true
    ).trim()

    if (!path) {
        error "✗ No Dockerfile found anywhere under ${serviceDir} — aborting."
    }

    return path
}
