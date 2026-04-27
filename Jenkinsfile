pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/sa8aa/my-djanjo-app.git'
            }
        }
    }

    post {
        success { echo 'Checkout successful!' }
        failure { echo 'Checkout failed!' }
    }
}
