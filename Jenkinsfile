pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build test') {
            steps {
                sh 'echo "Build running"'
                sh 'ls -la'
            }
        }

    }
}