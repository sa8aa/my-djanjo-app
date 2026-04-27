pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/your-username/your-repo.git'
            }
        }
    }

    post {
        success { echo 'Checkout successful!' }
        failure { echo 'Checkout failed!' }
    }
}
