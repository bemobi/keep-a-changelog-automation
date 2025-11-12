#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Função para extrair issue do Jira de uma string
# Procura por padrões como: [FS-123], FS-123:, FS-123 em qualquer parte do texto
extract_issue() {
    local text="$1"
    # Tenta vários padrões
    if [[ $text =~ \[([A-Z]{2,10}-[0-9]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    if [[ $text =~ ([A-Z]{2,10}-[0-9]+): ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    if [[ $text =~ ([A-Z]{2,10}-[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
}

# Função para detectar issue de múltiplas fontes (para o intervalo de commits especificado)
detect_issue() {
    local from_ref="$1"
    local to_ref="$2"
    local check_branch="$3"  # Se deve verificar o nome da branch

    local issue_key=""

    # 1. Tenta extrair do nome da branch atual (apenas se for HEAD - mudanças atuais)
    if [ "$check_branch" = "true" ]; then
        local branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        issue_key=$(extract_issue "$branch_name")
        if [ -n "$issue_key" ]; then
            echo "$issue_key"
            return
        fi
    fi

    # 2. Tenta extrair dos commits deste intervalo específico
    local commits
    if [ -z "$from_ref" ]; then
        commits=$(git log --pretty=format:"%s" "$to_ref" 2>/dev/null || echo "")
    else
        commits=$(git log --pretty=format:"%s" "$from_ref..$to_ref" 2>/dev/null || echo "")
    fi

    while IFS= read -r commit; do
        [ -z "$commit" ] && continue
        issue_key=$(extract_issue "$commit")
        if [ -n "$issue_key" ]; then
            echo "$issue_key"
            return
        fi
    done <<< "$commits"

    # 3. Se ainda não encontrou, tenta do nome da tag de destino
    if [ -n "$to_ref" ] && [[ "$to_ref" != "HEAD" ]]; then
        issue_key=$(extract_issue "$to_ref")
        if [ -n "$issue_key" ]; then
            echo "$issue_key"
            return
        fi
    fi

    # 4. Tenta extrair do nome da tag de origem
    if [ -n "$from_ref" ] && [[ "$from_ref" != "HEAD" ]]; then
        issue_key=$(extract_issue "$from_ref")
        if [ -n "$issue_key" ]; then
            echo "$issue_key"
            return
        fi
    fi

    # Não encontrou nada
    echo ""
}

# Função para processar commits e gerar conteúdo do changelog
process_commits() {
    local from_ref="$1"
    local to_ref="$2"
    local issue_key="$3"  # Issue já detectada (opcional)

    local commits
    if [ -z "$from_ref" ]; then
        commits=$(git log --pretty=format:"%s" "$to_ref")
    else
        commits=$(git log --pretty=format:"%s" "$from_ref..$to_ref")
    fi

    # Categoriza os commits
    local -a added_items=()
    local -a changed_items=()
    local -a fixed_items=()
    local -a breaking_items=()

    while IFS= read -r commit; do
        # Ignora linhas vazias
        [ -z "$commit" ] && continue

        # Remove prefixos comuns de commit
        commit_msg=$(echo "$commit" | sed -E 's/^(feat|fix|chore|refactor|docs|style|test|perf):\s*//')

        # Remove referências de issue do commit message para não duplicar
        commit_msg=$(echo "$commit_msg" | sed -E 's/\[?[A-Z]{2,10}-[0-9]+\]?:?\s*//')
        commit_msg=$(echo "$commit_msg" | sed -E 's/^[A-Z]{2,10}-[0-9]+:?\s*//')

        # Categoriza baseado no prefixo do commit
        if [[ $commit =~ ^feat ]]; then
            added_items+=("$commit_msg")
        elif [[ $commit =~ ^fix ]]; then
            fixed_items+=("$commit_msg")
        elif [[ $commit =~ ^refactor ]] || [[ $commit =~ ^chore ]]; then
            changed_items+=("$commit_msg")
        elif [[ $commit =~ BREAKING ]]; then
            breaking_items+=("$commit_msg")
        else
            changed_items+=("$commit_msg")
        fi
    done <<< "$commits"

    # Formata o issue link se encontrado
    local issue_prefix=""
    if [ -n "$issue_key" ]; then
        issue_prefix="**[[$issue_key](https://one-bemobi.atlassian.net/browse/$issue_key)]** "
    fi

    # Monta o conteúdo
    local content=""

    # Adiciona seção Added se houver itens
    if [ ${#added_items[@]} -gt 0 ]; then
        content="${content}\n### Added"
        for item in "${added_items[@]}"; do
            content="${content}\n- ${issue_prefix}${item}"
        done
        content="${content}\n"
    fi

    # Adiciona seção Changed se houver itens
    if [ ${#changed_items[@]} -gt 0 ]; then
        content="${content}\n### Changed"
        for item in "${changed_items[@]}"; do
            content="${content}\n- ${issue_prefix}${item}"
        done
        content="${content}\n"
    fi

    # Adiciona seção Fixed se houver itens
    if [ ${#fixed_items[@]} -gt 0 ]; then
        content="${content}\n### Fixed"
        for item in "${fixed_items[@]}"; do
            content="${content}\n- ${issue_prefix}${item}"
        done
        content="${content}\n"
    fi

    # Adiciona seção Breaking Changes se houver itens
    if [ ${#breaking_items[@]} -gt 0 ]; then
        content="${content}\n### BREAKING CHANGES"
        for item in "${breaking_items[@]}"; do
            content="${content}\n- ${issue_prefix}${item}"
        done
        content="${content}\n"
    fi

    echo -e "$content"
}

# Função para gerar changelog completo a partir de todas as tags
generate_full_changelog() {
    log_info "Generating full changelog from git history..."

    # Cria o header do changelog
    cat > "$CHANGELOG_FILE" <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

EOF

    # Obtém todas as tags ordenadas da mais ANTIGA para a mais RECENTE
    # Filtra apenas tags de versão (ignora -rc, -beta, -alpha, etc)
    local all_tags=($(git tag --sort=v:refname))  # Ordem crescente (antiga -> recente)
    local tags=()

    for tag in "${all_tags[@]}"; do
        # Ignora tags com sufixos como -rc, -beta, -alpha, -dev, etc
        if [[ ! "$tag" =~ -[a-zA-Z] ]]; then
            tags+=("$tag")
        else
            log_info "Skipping tag with suffix: $tag"
        fi
    done

    if [ ${#tags[@]} -eq 0 ]; then
        log_warning "No tags found in repository"
        # Adiciona todos os commits em Unreleased
        local issue_key=$(detect_issue "" "HEAD" "true")
        local content=$(process_commits "" "HEAD" "$issue_key")

        echo -e "$content" >> "$CHANGELOG_FILE"
        return
    fi

    # Armazena versões em ordem reversa para escrever no arquivo
    local versions_content=()

    # Processa cada tag (da mais antiga para a mais recente)
    local prev_tag=""
    for tag in "${tags[@]}"; do
        local tag_date=$(git log -1 --format=%ai "$tag" | awk '{print $1}' | sed 's/-/-/g' | awk -F- '{print $1"-"$3"-"$2}')

        log_info "Processing tag: $tag"

        # Detecta issue usando função aprimorada - PARA ESTE INTERVALO ESPECÍFICO
        # Intervalo correto: prev_tag..tag (da anterior até a atual)
        local issue_key
        if [ -z "$prev_tag" ]; then
            issue_key=$(detect_issue "" "$tag" "false")
        else
            issue_key=$(detect_issue "$prev_tag" "$tag" "false")
        fi

        if [ -n "$issue_key" ]; then
            log_info "  Issue detected: $issue_key"
        else
            log_warning "  No issue detected for tag $tag"
        fi

        # Processa commits desde a tag anterior (ou desde o início)
        local content
        if [ -z "$prev_tag" ]; then
            content=$(process_commits "" "$tag" "$issue_key")
        else
            content=$(process_commits "$prev_tag" "$tag" "$issue_key")
        fi

        # Armazena o conteúdo da versão (será escrito em ordem reversa depois)
        local version_entry="## [$tag] - $tag_date\n\n$content"
        versions_content+=("$version_entry")

        prev_tag="$tag"
    done

    # Escreve as versões em ordem reversa (mais recente primeiro)
    for ((i=${#versions_content[@]}-1; i>=0; i--)); do
        echo -e "${versions_content[$i]}" >> "$CHANGELOG_FILE"
    done

    # Adiciona links de comparação (em ordem reversa também - mais recente primeiro)
    echo "" >> "$CHANGELOG_FILE"
    local latest_tag="${tags[${#tags[@]}-1]}"  # Última tag do array = mais recente
    echo "[Unreleased]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/HEAD..$latest_tag" >> "$CHANGELOG_FILE"

    # Links em ordem reversa (mais recente primeiro)
    for ((i=${#tags[@]}-1; i>=0; i--)); do
        local current_tag="${tags[$i]}"
        if [ $i -eq 0 ]; then
            # Primeira tag (mais antiga) - link para a tag em si
            echo "[$current_tag]: https://bitbucket.org/git-m4u/s3-logs-reader/src/$current_tag" >> "$CHANGELOG_FILE"
        else
            # Tags intermediárias - link de comparação com a anterior
            local previous_tag="${tags[$((i-1))]}"
            echo "[$current_tag]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/$current_tag..$previous_tag" >> "$CHANGELOG_FILE"
        fi
    done

    log_info "Full changelog generated successfully!"
}

# Função para atualizar Unreleased com commits do branch atual
update_unreleased() {
    log_info "Updating [Unreleased] section with current branch commits..."

    # Verifica se CHANGELOG existe
    if [ ! -f "$CHANGELOG_FILE" ]; then
        generate_full_changelog
        return
    fi

    # Obtém a última tag
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    # Detecta issue usando função aprimorada - VERIFICA BRANCH PARA MUDANÇAS ATUAIS
    local issue_key
    if [ -z "$last_tag" ]; then
        issue_key=$(detect_issue "" "HEAD" "true")
    else
        issue_key=$(detect_issue "$last_tag" "HEAD" "true")
    fi

    if [ -n "$issue_key" ]; then
        log_info "Issue detected: $issue_key"
    else
        log_warning "No issue detected for current changes"
    fi

    local content
    if [ -z "$last_tag" ]; then
        content=$(process_commits "" "HEAD" "$issue_key")
    else
        content=$(process_commits "$last_tag" "HEAD" "$issue_key")
    fi

    # Se não houver commits novos, não faz nada
    if [ -z "$content" ] || [ "$content" = "\n" ]; then
        log_warning "No new commits found since last tag: ${last_tag:-<none>}"
        return
    fi

    # Atualiza a seção Unreleased
    awk -v new_content="$content" '
    BEGIN {
        in_unreleased = 0
        unreleased_found = 0
    }
    /^## \[Unreleased\]/ {
        in_unreleased = 1
        unreleased_found = 1
        print $0
        print ""
        printf "%s", new_content
        next
    }
    /^## \[/ {
        if (in_unreleased) {
            in_unreleased = 0
        }
        print $0
        next
    }
    /^### (Added|Changed|Fixed|BREAKING CHANGES)/ {
        if (in_unreleased) {
            next
        }
        print $0
        next
    }
    /^- / {
        if (in_unreleased) {
            next
        }
        print $0
        next
    }
    { print $0 }
    ' "$CHANGELOG_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$CHANGELOG_FILE"
    log_info "Unreleased section updated successfully!"
}

# Função para adicionar nova versão ao changelog
add_version_to_changelog() {
    local tag_version="$1"
    local current_date=$(date +"%Y-%d-%m")

    log_info "Adding version $tag_version to CHANGELOG.md"

    # Obtém a última tag
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    # Detecta issue usando função aprimorada - VERIFICA BRANCH PARA VERSÃO ATUAL
    local issue_key
    if [ -z "$last_tag" ]; then
        log_warning "No previous tag found, collecting all commits"
        issue_key=$(detect_issue "" "HEAD" "true")
    else
        log_info "Collecting commits since last tag: ${last_tag}"
        issue_key=$(detect_issue "$last_tag" "HEAD" "true")
    fi

    if [ -n "$issue_key" ]; then
        log_info "Issue detected: $issue_key"
    else
        log_warning "No issue detected for version $tag_version"
    fi

    local content
    if [ -z "$last_tag" ]; then
        content=$(process_commits "" "HEAD" "$issue_key")
    else
        content=$(process_commits "$last_tag" "HEAD" "$issue_key")
    fi

    # Cria o novo conteúdo da versão
    local new_version_content="## [$tag_version] - $current_date\n\n${content}"

    # Move conteúdo [Unreleased] para a nova versão e atualiza o CHANGELOG
    awk -v new_version="$new_version_content" -v tag="$tag_version" -v prev_tag="$last_tag" '
    BEGIN {
        in_unreleased = 0
        new_version_printed = 0
        has_links = 0
    }
    /^## \[Unreleased\]/ {
        in_unreleased = 1
        print $0
        print ""
        next
    }
    /^## \[/ {
        if (in_unreleased && !new_version_printed) {
            printf "%s\n", new_version
            new_version_printed = 1
        }
        in_unreleased = 0
        print $0
        next
    }
    /^### (Added|Changed|Fixed|BREAKING CHANGES)/ {
        if (in_unreleased) {
            next
        }
        print $0
        next
    }
    /^- / {
        if (in_unreleased) {
            next
        }
        print $0
        next
    }
    /^\[Unreleased\]:/ {
        has_links = 1
        printf "[Unreleased]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/HEAD..%s\n", tag
        if (prev_tag != "") {
            printf "[%s]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/%s..%s\n", tag, tag, prev_tag
        } else {
            printf "[%s]: https://bitbucket.org/git-m4u/s3-logs-reader/src/%s\n", tag, tag
        }
        next
    }
    /^\[.*\]:/ {
        print $0
        next
    }
    {
        if (!in_unreleased) {
            print $0
        }
    }
    END {
        if (!has_links) {
            print ""
            printf "[Unreleased]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/HEAD..%s\n", tag
            if (prev_tag != "") {
                printf "[%s]: https://bitbucket.org/git-m4u/s3-logs-reader/branches/compare/%s..%s\n", tag, tag, prev_tag
            } else {
                printf "[%s]: https://bitbucket.org/git-m4u/s3-logs-reader/src/%s\n", tag, tag
            }
        }
    }
    ' "$CHANGELOG_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$CHANGELOG_FILE"
    log_info "Version $tag_version added successfully!"
}

# ====================
# MAIN SCRIPT
# ====================

CHANGELOG_FILE="CHANGELOG.md"
TEMP_FILE="${CHANGELOG_FILE}.tmp"

# Cenário 1: Sem argumentos - atualiza [Unreleased]
if [ -z "$1" ]; then
    log_info "No tag version provided. Updating [Unreleased] section..."
    update_unreleased

    echo ""
    log_warning "Please review the CHANGELOG.md file before committing!"
    echo ""
    log_info "To commit the changes, run:"
    echo "  git add CHANGELOG.md"
    echo "  git commit -m \"docs: update CHANGELOG [Unreleased] section\""
    echo "  git push"
    exit 0
fi

TAG_VERSION="$1"

# Cenário 2: CHANGELOG não existe - gera histórico completo
if [ ! -f "$CHANGELOG_FILE" ]; then
    log_warning "CHANGELOG.md not found! Generating full changelog from git history..."
    generate_full_changelog

    # Agora adiciona a nova versão
    add_version_to_changelog "$TAG_VERSION"

    echo ""
    log_info "CHANGELOG.md created and version $TAG_VERSION added successfully!"
    echo ""
    log_warning "Please review the CHANGELOG.md file before committing!"
    echo ""
    log_info "To commit the changes, run:"
    echo "  git add CHANGELOG.md"
    echo "  git commit -m \"docs: create CHANGELOG and add version $TAG_VERSION\""
    echo "  git push"
    exit 0
fi

# Cenário 3: CHANGELOG existe - adiciona nova versão
add_version_to_changelog "$TAG_VERSION"

echo ""
log_info "CHANGELOG.md updated successfully!"
echo ""
log_warning "Please review the CHANGELOG.md file before committing!"
echo ""
log_info "To commit the changes, run:"
echo "  git add CHANGELOG.md"
echo "  git commit -m \"docs: update CHANGELOG for version $TAG_VERSION\""
echo "  git push"
