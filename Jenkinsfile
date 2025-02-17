pipeline {
    agent any

    environment {
        AZURE_CREDENTIALS = credentials('azure-service-principal')
        TF_DIR            = 'terraform'
    }

    stages {
        stage('Clone Repository') {
            steps {
                 git branch: 'main', credentialsId: 'git-ssh-key', url: 'https://github.com/sid326/PostgresTerrformDeployment.git'
            }
        }

        stage('Azure Login') {
                            steps {
                                script {
                                    withCredentials([azureServicePrincipal('azure-service-principal')]) {
                                        sh '''
                                           az login --service-principal \
                                              -u $AZURE_CREDENTIALS_CLIENT_ID \
                                              -p $AZURE_CREDENTIALS_CLIENT_SECRET \
                                              --tenant $AZURE_CREDENTIALS_TENANT_ID

                                           az account set --subscription $AZURE_CREDENTIALS_SUBSCRIPTION_ID
                                        '''
                                    }
                                }
                            }
                        }

        stage('Terraform Init') {
                    steps {
                        dir("${TF_DIR}") {
                            sh 'terraform init'
                        }
                    }
                }

        stage('Plan Terraform Deployment') {
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform plan -out=tfplan'
                  }
            }
        }

        stage('Apply Terraform Configuration') {
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'terraform.tfstate', fingerprint: true
        }
        success {
            echo "Terraform Deployment Successful!"
        }
        failure {
            echo "Terraform Deployment Failed!"
        }
    }
}
