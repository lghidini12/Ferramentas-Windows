# 🛠️ Ferramentas Windows

Repositório de ferramentas e scripts pessoais para automação, manutenção e produtividade no Windows.

Cada ferramenta é independente e documentada abaixo. A ideia é manter o PC organizado, automatizar tarefas repetitivas e ter scripts prontos para uso quando necessário.

***

## 📋 Índice

- [limpeza-sistema.ps1](#limpeza-sistemaps1)

***

## limpeza-sistema.ps1

Interface gráfica em PowerShell (WinForms) para escanear, selecionar e remover programas instalados, além de limpar pastas de cache e resíduos de ferramentas de desenvolvimento.

### O que faz

- Lista todos os programas instalados no Windows via registro do sistema
- Detecta e lista pastas de cache comuns de ferramentas como `pip`, `npm`, `Maven`, `Gradle`, `.cargo`, entre outras
- Destaca em vermelho claro itens sensíveis, como drivers, Visual C++ e componentes de hardware, para evitar remoção acidental
- Permite simular a limpeza antes de executar qualquer ação real
- Exige confirmação em múltiplas etapas antes de desinstalar ou apagar qualquer item
- Copia a seleção para a área de transferência para compartilhar ou arquivar

### Pré-requisitos

- Windows 10 ou Windows 11
- Windows PowerShell 5.1 ou superior

### Como usar

> **Não dê duplo clique no arquivo.** Scripts `.ps1` não são executáveis diretamente pelo Explorer.

**Passo 1:** Abra o Explorer na pasta onde o script está salvo.

**Passo 2:** Clique na barra de endereço do Explorer, digite `powershell` e pressione Enter.

**Passo 3:** No terminal aberto, execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\limpeza-sistema.ps1
```

Ou, se preferir uma linha só:

```powershell
powershell -ExecutionPolicy Bypass -File ".\limpeza-sistema.ps1"
```

> Recomenda-se abrir o PowerShell como **Administrador** para que as desinstalações funcionem corretamente.

### Botões

| Botão | O que faz |
|---|---|
| **Escanear sistema** | Varre o registro do Windows e pastas comuns de cache e popula a tabela |
| **Selecionar tudo** | Marca todos os itens visíveis na tabela |
| **Limpar seleção** | Desmarca todos os itens |
| **Simular limpeza** | Mostra no log o que seria removido, sem executar nada |
| **Copiar seleção** | Copia a lista dos itens marcados para a área de transferência |
| **Realizar limpeza** | Executa a desinstalação e limpeza dos itens marcados, após confirmação |

### Cores na tabela

| Cor | Significado |
|---|---|
| Vermelho claro | Item sensível — driver, runtime ou componente do sistema. Revise antes de remover. |
| Branco | Item comum, sem risco especial identificado. |

### Aviso

Itens em vermelho claro incluem componentes como:

- **Microsoft Visual C++ Redistributable** — muitos programas e jogos dependem dessas bibliotecas
- **Drivers e software AMD / Intel / NVIDIA** — ligados ao funcionamento do hardware
- **Microsoft Edge / WebView2** — usados pelo sistema e por vários aplicativos

Remover esses itens sem necessidade pode quebrar outros programas. O script solicita confirmação extra ao detectar itens sensíveis na seleção.

### Categorias escaneadas

| Categoria | Exemplos |
|---|---|
| Programas | Todos os apps instalados no registro do Windows |
| Caches | Temp do usuário, Temp local |
| Python | `pip cache` em AppData e LocalAppData |
| Node | `npm-cache`, pasta `npm` no Roaming, `.npm` do usuário |
| Java | `.m2` (Maven), `.gradle` (Gradle) |
| NuGet | `.nuget` do usuário |
| Rust | `.cargo` do usuário |
| Go | pasta `go` do usuário |
| Android | `.android` do usuário |
| VS Code | `.vscode` do usuário |

***

## Contribuindo

Este é um repositório pessoal. Sugestões e melhorias são bem-vindas via Issues ou Pull Requests.

***

## Licença

MIT — use, modifique e distribua livremente.
