pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME            = 'sa8aa/my-djanjo-app'
        AWS_REGION     = 'us-east-1'
        AWS_ACCOUNT_ID = '271744664756'
        ECR_REPO       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/my-djanjo-app"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        KEY_NAME       = 'vockey'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sa8aa/my-djanjo-app.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    set -e
                    python3 -m venv venv
                    venv/bin/python -m pip install --upgrade pip --quiet
                    venv/bin/python -m pip install -r requirements.txt --quiet
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    set -e
                    venv/bin/python manage.py test
                '''
            }
        }

        stage('Build & Push Images') {       // ← merged into one stage
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId:    'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable:      'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        # ── Build once ────────────────────────────────────────
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

                        # ── Push to DockerHub ─────────────────────────────────
                        echo \$DOCKERHUB_CREDENTIALS_PSW | docker login \
                            -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest

                        # ── Create ECR repo if needed ─────────────────────────
                        aws ecr describe-repositories \
                            --repository-names my-djanjo-app \
                            --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository \
                            --repository-name my-djanjo-app \
                            --region ${AWS_REGION}

                        # ── Push to ECR ───────────────────────────────────────
                        AWS_PASS=\$(aws ecr get-login-password --region ${AWS_REGION})
                        echo "\$AWS_PASS" | docker login \
                            --username AWS \
                            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest

                        echo "✅ Images pushed to DockerHub and ECR"
                    """
                }
            }
            post {
                success { echo "✅ Build and push successful" }
                failure { echo "❌ Build or push failed" }
            }
        }

        stage('Provision Infra') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId:    'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable:      'AWS_SESSION_TOKEN'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {
                    sh """
                        export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        STACK_STATUS=\$(aws cloudformation describe-stacks \
                            --stack-name my-djanjo-app-infra \
                            --region ${AWS_REGION} \
                            --query 'Stacks[0].StackStatus' \
                            --output text 2>/dev/null || echo "DOES_NOT_EXIST")

                        echo "Stack status: \$STACK_STATUS"

                        if [ "\$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
                            echo "Creating stack..."
                            aws cloudformation create-stack \
                                --stack-name my-djanjo-app-infra \
                                --capabilities CAPABILITY_IAM \
                                --template-body file://cloudformation/infra-stack.yaml \
                                --parameters \
                                    ParameterKey=ProjectName,ParameterValue=my-djanjo-app \
                                    ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
                                --region ${AWS_REGION}

                            aws cloudformation wait stack-create-complete \
                                --stack-name my-djanjo-app-infra \
                                --region ${AWS_REGION}

                        elif [ "\$STACK_STATUS" = "CREATE_COMPLETE" ] || \
                             [ "\$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
                            echo "Stack already exists — skipping creation"

                        else
                            echo "Stack in unexpected status: \$STACK_STATUS"
                            exit 1
                        fi

                        EC2_IP=\$(aws cloudformation describe-stacks \
                            --stack-name my-djanjo-app-infra \
                            --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \
                            --output text \
                            --region ${AWS_REGION})

                        echo "EC2 IP: \$EC2_IP"
                        echo \$EC2_IP > /tmp/ec2-ip.txt

                        chmod 400 \${SSH_KEY}

                        for i in \$(seq 1 30); do
                            STATUS=\$(ssh -i \${SSH_KEY} \
                                -o StrictHostKeyChecking=no \
                                -o ConnectTimeout=10 \
                                ec2-user@\$EC2_IP \
                                "sudo kubectl get nodes 2>/dev/null | grep Ready || echo NOT_READY")

                            if echo "\$STATUS" | grep -q "Ready"; then
                                echo "✅ k3s is ready: \$STATUS"
                                break
                            fi

                            echo "Attempt \$i/30 — not ready yet, waiting 10s..."
                            sleep 10

                            if [ \$i -eq 30 ]; then
                                echo "❌ k3s did not become ready in time"
                                exit 1
                            fi
                        done

                        echo "✅ Infra ready at: \$EC2_IP"
                    """
                }
            }
            post {
                success { echo "✅ Infrastructure provisioned successfully" }
                failure { echo "❌ CloudFormation or k3s setup failed" }
            }
        }

        stage('Deploy to k3s') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId:    'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable:      'AWS_SESSION_TOKEN'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {
                    sh """
                        export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        EC2_IP=\$(cat /tmp/ec2-ip.txt)
                        ECR_PASSWORD=\$(aws ecr get-login-password --region ${AWS_REGION})

                        # Configure k3s ECR registry auth
                        ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo mkdir -p /etc/rancher/k3s"

                        echo "mirrors:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "    endpoint:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "      - https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "configs:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "    auth:" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "      username: AWS" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"
                        echo "      password: \$ECR_PASSWORD" | ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null"

                        # Restart k3s and deploy
                        ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo systemctl restart k3s && sleep 15"

                        scp -i \${SSH_KEY} -o StrictHostKeyChecking=no \
                            k8s/deployment.yaml k8s/service.yaml \
                            ec2-user@\$EC2_IP:/home/ec2-user/

                        ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo kubectl apply -f /home/ec2-user/deployment.yaml && \
                             sudo kubectl apply -f /home/ec2-user/service.yaml"

                        ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@\$EC2_IP \
                            "sudo kubectl rollout status deployment/my-djanjo-app --timeout=180s"

                        echo "✅ App deployed at http://\$EC2_IP:30080"
                    """
                }
            }
            post {
                success { echo "✅ Deployment successful" }
                failure { echo "❌ Deployment failed" }
            }
        }

    }

    post {
        always {
            sh 'docker logout || true'
            cleanWs()
        }
        success { echo "🚀 Pipeline completed successfully." }
        failure { echo "💥 Pipeline failed." }
    }
}
