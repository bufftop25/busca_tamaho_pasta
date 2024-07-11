#!/bin/bash
wget -O /home/deploy/atualiza_public.sh https://raw.githubusercontent.com/FilipeCamillo/busca_tamaho_pasta/main/busca_tamaho_pasta.sh
# Carregar variáveis de ambiente do arquivo .env
source "/home/deploy/workzap/backend/.env"

# Caminho para a pasta public
PUBLIC_FOLDER="/home/deploy/workzap/backend/public"

# Testar a conexão com o banco de dados
if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null; then
    echo "Conexão com o banco de dados bem-sucedida."
else
    echo "Erro: Não foi possível conectar ao banco de dados."
    exit 1
fi

# Função para extrair apenas números de uma string
extract_numbers() {
    local input=$1
    local output=$(echo "$input" | tr -cd '[:digit:]')
    echo "$output"
}

# Função para obter a data e hora atual no formato SQL
get_current_date() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Loop para processar cada pasta na pasta public
for folder in "$PUBLIC_FOLDER"/*; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        # Extrair o ID da company do nome da pasta
        company_id=$(extract_numbers "$folder_name")
        
        # Verificar se a company existe antes de tentar atualizar seus dados
        if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT 1 FROM public.\"Companies\" WHERE id = '$company_id');" | grep -q 't'; then
            num_files=$(find "$folder" -type f | wc -l)
            folder_size=$(du -sh "$folder" | awk '{print $1}')
            update_date=$(get_current_date)

             # Comando SQL para realizar a atualização
            sql_command="UPDATE public.\"Companies\" 
                         SET \"folderSize\" = '$folder_size', 
                             \"numberFileFolder\" = '$num_files', 
                             \"updatedAtFolder\" = '$update_date' 
                         WHERE id = '$company_id';"

            # Executar o comando SQL utilizando psql
            PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$sql_command"
            
            echo "Dados da empresa ID $company_id atualizados com sucesso."
        else
            echo "Erro: A empresa com o ID $company_id não foi encontrada."
        fi
    fi
done

echo "Rotina concluída"