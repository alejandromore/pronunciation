@Library('shared-lib') _

pipeline {
    agent {
        label 'agent-huawei'
    }

    options {
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'PROJECT',
            defaultValue: 'pronunciation',
            description: 'Project / Environment (prefijo de recursos: vpc-<PROJECT>, ecs-<PROJECT>-app, obs-<PROJECT>-data, etc.)'
        )
        choice(
            name: 'ACTION',
            choices: ['deploy', 'destroy'],
            description: 'Accion sobre el ambiente'
        )
        booleanParam(
            name: 'RUN_TERRAFORM',
            defaultValue: false,
            description: 'Construir/destruir la infraestructura (VPC, ECS GPU con EIP, OBS+CSV, agency)'
        )
        booleanParam(
            name: 'DEPLOY_PRONUNCIATION',
            defaultValue: true,
            description: 'Desplegar el AI Pronunciation Trainer (contenedor GPU + nginx HTTPS) en el ECS.'
        )
    }

    environment {
        TF_DIR     = 'terraform'
        ANS_DIR    = 'ansible'
        OBS_REGION = 'la-south-2'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // -- Terraform (deploy o destroy) --
        stage('Terraform') {
            when {
                expression { params.RUN_TERRAFORM }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'hwc-access-key', variable: 'HW_ACCESS_KEY'),
                    string(credentialsId: 'hwc-secret-key', variable: 'HW_SECRET_KEY'),
                    string(credentialsId: 'hwc-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'hwc-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        terraformDeploy(
                            dir: env.TF_DIR,
                            varsFile: 'terraform.tfvars',
                            project: env.PROJECT,
                            action: params.ACTION,
                            // El ECS tiene EIP directa (sin bastion). Terraform sube
                            // el CSV a OBS y el ECS lo lee por agency.
                            outputs: [
                                'app_public_ip', 'ecs_private_key',
                                'obs_data_bucket', 'obs_csv_key'
                            ]
                        )
                    }
                }
            }
        }

        // -- Cargar outputs de Terraform --
        stage('Load Terraform Outputs') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    env.app_public_ip   = readFile("${WORKSPACE}/app_public_ip.txt").trim()
                    env.ecs_private_key = "${WORKSPACE}/ecs_private_key.txt"
                    env.obs_data_bucket = readFile("${WORKSPACE}/obs_data_bucket.txt").trim()
                    env.obs_csv_key     = readFile("${WORKSPACE}/obs_csv_key.txt").trim()

                    echo "App Public IP:   ${env.app_public_ip}"
                    echo "OBS data bucket: ${env.obs_data_bucket}"
                    echo "OBS csv key:     ${env.obs_csv_key}"
                    echo "App URL (HTTPS): https://${env.app_public_ip}"
                }
            }
        }

        // -- Ansible: desplegar el Pronunciation Trainer (SSH directo a la EIP) --
        stage('Deploy Pronunciation with Ansible') {
            when {
                allOf {
                    expression { params.ACTION == 'deploy' }
                    expression { params.DEPLOY_PRONUNCIATION }
                }
            }
            steps {
                dir(env.ANS_DIR) {
                    withCredentials([
                        usernamePassword(credentialsId: 'swr-jenkins', usernameVariable: 'SWR_USER', passwordVariable: 'SWR_PASS')
                    ]) {
                        withEnv([
                            "KEY=${env.ecs_private_key}",
                            "APP_PUBLIC_IP=${env.app_public_ip}",
                            "OBS_BUCKET=${env.obs_data_bucket}",
                            "OBS_CSV_KEY=${env.obs_csv_key}",
                            "APP_ENV=${params.PROJECT}"
                        ]) {
                            sh '''
                                set -e
                                chmod 600 "$KEY"
                                export ANSIBLE_HOST_KEY_CHECKING=False

                                ansible-playbook -i inventory/hosts.yml playbooks/deploy-pronunciation.yml \\
                                    --private-key "$KEY" \\
                                    --extra-vars "app_env=$APP_ENV \\
                                                  app_public_ip=$APP_PUBLIC_IP \\
                                                  obs_region=$OBS_REGION \\
                                                  obs_bucket=$OBS_BUCKET \\
                                                  obs_csv_key=$OBS_CSV_KEY"

                                set +x
                                echo "============================================================"
                                echo " Pronunciation Trainer desplegado"
                                echo " App (HTTPS): https://$APP_PUBLIC_IP"
                                echo " CSV en OBS:  $OBS_BUCKET/$OBS_CSV_KEY"
                                echo " (Edita el CSV en OBS y reinicia el ECS para refrescarlo.)"
                                echo "============================================================"
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.ACTION == 'deploy') {
                    def ip = env.app_public_ip ?: 'N/A'
                    currentBuild.description = "Deploy OK - Trainer (HTTPS): https://${ip}"
                } else {
                    currentBuild.description = "Destruccion completada"
                }
            }
        }
        failure {
            script {
                currentBuild.description = "Fallo en: ${env.STAGE_NAME ?: 'N/A'} - Logs: ${env.BUILD_URL}console"
            }
        }
    }
}
