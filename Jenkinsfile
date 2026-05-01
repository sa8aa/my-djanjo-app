pipeline {
    agent any

    environment {
        DOCKER_IMAGE   = "samarbenromdhane/my-djanjo-app"
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "284208999443"
        ECR_REPO       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/my-djanjo-app"
        KUBE_CONFIG    = "/var/jenkins_home/.kube/config"
        ECR_KEEP       = "5"
        KEY_NAME       = "vockey"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'feature/jenkins-pipeline',
                    url: 'https://github.com/sa8aa/my-djanjo-app.git'
            }
            post {
                success {
                    script {
                        env.IMAGE_TAG = "v${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
                        echo "✅ Checkout OK"
                        echo "📌 Commit    : ${GIT_COMMIT}"
                        echo "🏷️  Image tag : ${env.IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Tests') {
            steps {
                sh 'chmod +x scripts/test.sh && bash scripts/test.sh'
            }
            post {
                success { echo "✅ Tests passed" }
                failure { echo "❌ Tests failed — pipeline aborted" }
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build \
                        -t ${DOCKER_IMAGE}:${IMAGE_TAG} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                """
            }
            post {
                success { echo "✅ Image built : ${DOCKER_IMAGE}:${IMAGE_TAG}" }
                failure { echo "❌ Docker build failed" }
            }
        }

        stage('Push DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'jenkins_djanjo_app',
                    usernameVariable: 'U',
                    passwordVariable: 'P'
                )]) {
                    sh """
                        echo \$P | docker login -u \$U --password-stdin
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    """
                }
            }
            post {
                success { echo "✅ Image pushed to DockerHub : ${DOCKER_IMAGE}:${IMAGE_TAG}" }
                failure { echo "❌ DockerHub push failed" }
            }
        }

        stage('Push ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        # ── Create ECR repo if not exists ──────────────────
                        REPO_EXISTS=\$(aws ecr describe-repositories \
                            --repository-names my-djanjo-app \
                            --region ${AWS_REGION} \
                            --query 'repositories[0].repositoryName' \
                            --output text 2>/dev/null || echo "NOT_FOUND")

                        if [ "\$REPO_EXISTS" = "NOT_FOUND" ]; then
                            echo "Creating ECR repository..."
                            aws ecr create-repository \
                                --repository-name my-djanjo-app \
                                --region ${AWS_REGION}
                            echo "✅ ECR repository created"
                        else
                            echo "✅ ECR repository already exists — skipping"
                        fi

                        # ── Login to ECR ───────────────────────────────────
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS \
                            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        # ── Tag and push ───────────────────────────────────
                        docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE}:latest ${ECR_REPO}:latest

                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest

                        echo "✅ Image pushed to ECR : ${ECR_REPO}:${IMAGE_TAG}"
                    """
                }
            }
            post {
                success { echo "✅ ECR push successful : ${ECR_REPO}:${IMAGE_TAG}" }
                failure { echo "❌ ECR push failed" }
            }
        }

        stage('Provision Infra') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    ),
                    file(
                        credentialsId: 'ec2-ssh-key',
                        variable: 'SSH_KEY'
                    )
                ]) {
                    sh """
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        # ── Detect if infra-stack.yaml was modified ────────
                        TEMPLATE_HASH=\$(md5sum cloudformation/infra-stack.yaml | cut -d' ' -f1)
                        HASH_FILE="/tmp/infra-stack-hash.txt"
                        PREVIOUS_HASH=\$(cat \$HASH_FILE 2>/dev/null || echo "NONE")

                        echo "Current  template hash : \$TEMPLATE_HASH"
                        echo "Previous template hash : \$PREVIOUS_HASH"

                        # ── Check if stack already exists ──────────────────
                        STACK_STATUS=\$(aws cloudformation describe-stacks \
                            --stack-name my-djanjo-app-infra \
                            --region ${AWS_REGION} \
                            --query 'Stacks[0].StackStatus' \
                            --output text 2>/dev/null || echo "DOES_NOT_EXIST")

                        echo "Stack status: \$STACK_STATUS"

                        if [ "\$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
                            echo "Stack does not exist — creating..."
                            aws cloudformation create-stack \
                                --stack-name my-djanjo-app-infra \
                                --template-body file://cloudformation/infra-stack.yaml \
                                --parameters \
                                    ParameterKey=ProjectName,ParameterValue=my-djanjo-app \
                                    ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
                                --region ${AWS_REGION}

                            echo "Waiting for stack creation..."
                            aws cloudformation wait stack-create-complete \
                                --stack-name my-djanjo-app-infra \
                                --region ${AWS_REGION}

                            echo "✅ Stack created"
                            echo \$TEMPLATE_HASH > \$HASH_FILE

                        elif [ "\$STACK_STATUS" = "CREATE_COMPLETE" ] || \
                             [ "\$STACK_STATUS" = "UPDATE_COMPLETE" ]; then

                            if [ "\$TEMPLATE_HASH" != "\$PREVIOUS_HASH" ]; then
                                echo "Template modified — updating stack..."
                                aws cloudformation update-stack \
                                    --stack-name my-djanjo-app-infra \
                                    --template-body file://cloudformation/infra-stack.yaml \
                                    --parameters \
                                        ParameterKey=ProjectName,ParameterValue=my-djanjo-app \
                                        ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
                                    --region ${AWS_REGION}

                                echo "Waiting for stack update..."
                                aws cloudformation wait stack-update-complete \
                                    --stack-name my-djanjo-app-infra \
                                    --region ${AWS_REGION}

                                echo "✅ Stack updated"
                                echo \$TEMPLATE_HASH > \$HASH_FILE
                            else
                                echo "✅ Stack exists and template unchanged — skipping"
                            fi

                        else
                            echo "Stack in unexpected status: \$STACK_STATUS — check AWS Console"
                            exit 1
                        fi

                        # ── Get EC2 public IP ──────────────────────────────
                        EC2_IP=\$(aws cloudformation describe-stacks \
                            --stack-name my-djanjo-app-infra \
                            --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \
                            --output text \
                            --region ${AWS_REGION})

                        echo "EC2 IP: \$EC2_IP"
                        echo \$EC2_IP > /tmp/ec2-ip.txt

                        # ── Fix key permissions ────────────────────────────
                        cp \${SSH_KEY} /tmp/ec2-key.pem
                        chmod 400 /tmp/ec2-key.pem

                        # ── Wait for k3s to be ready (max 5 min) ──────────
                        echo "Waiting for k3s to be ready..."

                        for i in \$(seq 1 30); do
                            STATUS=\$(ssh -i /tmp/ec2-key.pem \
                                -o StrictHostKeyChecking=no \
                                -o ConnectTimeout=10 \
                                ec2-user@\$EC2_IP \
                                "sudo /usr/local/bin/k3s kubectl get nodes 2>/dev/null | grep Ready || echo NOT_READY")
                            if echo "\$STATUS" | grep -q "Ready"; then
                                echo "✅ k3s is ready : \$STATUS"
                                break
                            fi

                            echo "Attempt \$i/30 — k3s not ready yet, waiting 10s..."
                            sleep 10

                            if [ \$i -eq 30 ]; then
                                echo "❌ k3s did not become ready in time"
                                exit 1
                            fi
                        done

                        # ── Cleanup temp key ───────────────────────────────
                        rm -f /tmp/ec2-key.pem

                        echo "✅ Infrastructure provisioned and k3s ready at : \$EC2_IP"
                    """
                }
            }
            post {
                success { echo "✅ Infrastructure provisioned successfully" }
                failure { echo "❌ CloudFormation or k3s setup failed" }
            }
        }

    }

    post {
        always {
            sh """
                docker rmi ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                docker rmi ${ECR_REPO}:${IMAGE_TAG}     || true
                docker image prune -f                   || true
            """
        }
        success { echo "✅ Pipeline passed" }
        failure { echo "❌ Pipeline failed — check logs above" }
    }
}
