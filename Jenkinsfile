def imageTag = ''

pipeline {
    agent any

    environment {
        DOCKER_BUILDKIT = '1'
        BUILDKIT_PROGRESS = 'plain'
        HARBOR_PROJECT = 'sample-microservice'
        SONARQUBE_DEFAULT_URL = 'http://sonarqube:9000'
    }

    parameters {
        choice(
            name: 'BUILD_TARGET',
            choices: ['all', 'adservice', 'cartservice', 'checkoutservice', 'currencyservice', 
                     'emailservice', 'frontend', 'paymentservice', 'productcatalogservice', 
                     'recommendationservice', 'shippingservice', 'shoppingassistantservice'],
            description: 'Select which service(s) to build'
        )
        booleanParam(name: 'PUSH_IMAGES', defaultValue: true, description: 'Push Docker images to Harbor?')
        string(name: 'HARBOR_REGISTRY', defaultValue: 'localhost', description: 'Harbor registry URL (e.g., 192.168.1.100)')
        string(name: 'SONARQUBE_URL', defaultValue: 'http://sonarqube:9000', description: 'SonarQube server URL (leave empty to auto-detect)')
    }
 
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '✓ Checking out repository...'
                    checkout scm
                    echo "✓ Repository checked out - Commit: ${env.GIT_COMMIT}"
                }
            }
        }
        stage('SonarQube Analysis') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo '✓ Running SonarQube analysis...'

                    def shortCommit = env.GIT_COMMIT?.take(7) ?: 'unknown'
                    def buildVersion = "${env.BUILD_NUMBER}-${shortCommit}"

                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('sonarqube') {

                        sh """
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=microservices-demo \
                        -Dsonar.projectName="Microservices Demo" \
                        -Dsonar.projectVersion=${buildVersion} \
                        -Dsonar.sources=src \
                        -Dsonar.sourceEncoding=UTF-8 \
                        -Dsonar.exclusions=**/node_modules/**,**/test/**,**/tests/** \
                        -Dsonar.coverage.exclusions=**/test/**
                        """
                    }
                }
            }
}

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Validate Services') {
            steps {
                script {
                    echo '✓ Validating service structure...'
                    def services = getServiceList()
                    services.each { service ->
                        def dockerfilePath = getDockerfilePath(service)
                        if (fileExists(dockerfilePath)) {
                            echo "  ✓ Found: ${dockerfilePath}"
                        } else {
                            error "  ✗ Missing: ${dockerfilePath}"
                        }
                    }
                }
            }
        }

        stage('Prepare Image Tag') {
            steps {
                script {
                    def timestamp = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def buildNumber = env.BUILD_NUMBER ?: currentBuild.number.toString()
                    imageTag = "${buildNumber}-${timestamp}"
                    if (!imageTag?.trim()) {
                        error '✗ IMAGE_TAG is empty or null. Aborting pipeline.'
                    }
                    echo "✓ Image tag for this pipeline: ${imageTag}"
                }
            }
        }



        stage('Build Docker Images') {
            steps {
                script {
                    echo '✓ Building Docker images...'
                    def services = getBuildServices()
                    
                    services.each { service ->
                        def dockerfilePath = getDockerfilePath(service)
                        if (fileExists(dockerfilePath)) {
                            echo "  → Building Docker image: ${service}..."
                            
                            // Determine context directory based on service
                            def contextDir
                            if (service == 'cartservice') {
                                contextDir = 'src/cartservice/src'
                            } else {
                                contextDir = "src/${service}"
                            }
                            
                            dir(contextDir) {
                                sh """
                                    docker build \
                                        -f Dockerfile \
                                        -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:${imageTag} \
                                        -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:latest \
                                        .
                                """
                            }
                        } else {
                            echo "  ⚠ Warning: Dockerfile not found at ${dockerfilePath}, skipping ${service}"
                        }
                    }
                }
            }
        }

        stage('Push Docker Images') {
            when {
                expression { 
                    params.PUSH_IMAGES == true
                }
            }
            steps {
                script {
                    echo '✓ Pushing Docker images to Harbor registry...'
                    def services = getBuildServices()
                    echo "  → Using image tag: ${imageTag}"
                    
                    // Debug: Check connectivity to Harbor
                    echo "  → Testing connection to Harbor registry: ${HARBOR_REGISTRY}..."
                    sh '''
                        # Try to curl Harbor API to test connectivity
                        if curl -f -k https://${HARBOR_REGISTRY}/api/v2.0/health >/dev/null 2>&1; then
                            echo "  ✓ Harbor is reachable"
                        else
                            echo "  ⚠ Warning: Harbor may not be reachable at ${HARBOR_REGISTRY}"
                            echo "  → Checking if ${HARBOR_REGISTRY} is accessible..."
                            curl -v -k https://${HARBOR_REGISTRY}/api/v2.0/health || true
                        fi
                    '''
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkin-cred', 
                        usernameVariable: 'HARBOR_USER', 
                        passwordVariable: 'HARBOR_PASS')]) {
                        echo "  → Logging in to Harbor as: ${HARBOR_USER}"
                        sh '''
                            echo $HARBOR_PASS | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}
                        '''
                        
                        services.each { service ->
                            sh """
                                echo "  → Checking for image: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:${imageTag}"
                                if docker image inspect ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:${imageTag} >/dev/null 2>&1; then
                                    echo "  → Found image, pushing ${service}:${imageTag} and ${service}:latest..."
                                    docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:${imageTag}
                                    docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:latest
                                    echo "  ✓ ${service} pushed successfully"
                                else
                                    echo "  ⚠ Image not found: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${service}:${imageTag}"
                                fi
                            """
                        }
                        
                        sh 'docker logout || true'
                    }
                }
            }
        }

        stage('Security Scan') {
            when {
                expression { env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' }
            }
            steps {
                script {
                    echo '✓ Running security scans...'
                    // Add your security scanning tools here
                    // Example: trivy, snyk, or similar
                    sh 'echo "  → Security scan placeholder"'
                }
            }
        }

        stage('Deploy') {
            when {
                expression { env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' }
            }
            steps {
                script {
                    echo '✓ Deploying services...'
                    // Add your deployment logic here
                    // Examples:
                    // - docker-compose up
                    // - kubectl apply -f k8s/
                    // - Terraform apply
                    sh '''
                        echo "  → Deployment placeholder"
                        echo "  → Configure your deployment process here"
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '✓ Pipeline execution completed'
            sh 'docker logout || true'
        }
        failure {
            echo '✗ Pipeline failed!'
            // Send notifications
        }
        success {
            echo '✓ Pipeline succeeded!'
        }
    }
}

// ==================== Helper Functions ====================

def getServiceList() {
    return ['adservice', 'cartservice', 'checkoutservice', 'currencyservice',
            'emailservice', 'frontend', 'paymentservice', 'productcatalogservice',
            'recommendationservice', 'shippingservice', 'shoppingassistantservice']
}

def getBuildServices() {
    if (params.BUILD_TARGET == 'all') {
        return getServiceList()
    } else {
        return [params.BUILD_TARGET]
    }
}

def getDockerfilePath(String service) {
    // Handle special cases where Dockerfile is not in the root of service directory
    switch(service) {
        case 'cartservice':
            return "src/${service}/src/Dockerfile"
        default:
            return "src/${service}/Dockerfile"
    }
}

def getSonarQubeUrl(String paramUrl) {
    // Nếu parameter có giá trị, sử dụng nó
    if (paramUrl?.trim()) {
        return paramUrl.trim()
    }
    
    // Cố gắng auto-detect hostname
    try {
        def hostname = sh(script: 'hostname -f 2>/dev/null || hostname', returnStdout: true).trim()
        if (hostname) {
            return "http://${hostname}:9000"
        }
    } catch (Exception e) {
        // Nếu không lấy được hostname, sử dụng default
    }
    
    // Fallback về default URL
    return env.SONARQUBE_DEFAULT_URL ?: 'http://sonarqube:9000'
}