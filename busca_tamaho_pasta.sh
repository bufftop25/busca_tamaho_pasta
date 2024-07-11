#!/bin/bash

# Baixar o script de atualização
wget -O /home/deploy/atualiza_public.sh https://raw.githubusercontent.com/bufftop25/busca_tamaho_pasta/main/busca_tamaho_pasta.sh

# Encontrar todas as pastas que contêm o diretório backend
BASE_DIRS=$(find /home/deploy/ -type d -name backend | sed 's|/backend||')

# Verificar se algum diretório backend foi encontrado
if [ -z "$BASE_DIRS" ]; then
    echo "Erro: Não foi possível encontrar nenhum diretório backend."
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

# Processar cada diretório que contém o backend
for BASE_DIR in $BASE_DIRS; do

    # Carregar variáveis de ambiente do arquivo .env
    if [ -f "$BASE_DIR/backend/.env" ]; then
        source "$BASE_DIR/backend/.env"
    else
        echo "Erro: Arquivo .env não encontrado em $BASE_DIR/backend."
        continue
    fi

    # Caminho para a pasta public
    PUBLIC_FOLDER="$BASE_DIR/backend/public"

    # Testar a conexão com o banco de dados
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null; then
        echo "Conexão com o banco de dados bem-sucedida para $BASE_DIR."
    else
        echo "Erro: Não foi possível conectar ao banco de dados para $BASE_DIR."
        continue
    fi

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
                
                echo "Dados da empresa ID $company_id atualizados com sucesso para $BASE_DIR."
            else
                echo "Erro: A empresa com o ID $company_id não foi encontrada para $BASE_DIR."
            fi
        fi
    done

done

echo "Rotina concluída"
