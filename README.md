# windows-startup

Script de PowerShell para abrir, em sequência, os apps de trabalho ao ligar
o Windows: Docker Desktop, VSCode, o app desktop do Claude, o Chrome (num
perfil específico, direto numa URL) e, opcionalmente, o
[Code Watcher](https://github.com/ndmg-dev/CodeWatcher).

## Uso

1. Edite as variáveis marcadas com `<PREENCHER: ...>` no topo de
   [`startup.ps1`](startup.ps1) com os caminhos e valores da sua máquina.
2. Registre o script para rodar no boot — por exemplo, criando um atalho
   para ele na pasta de Inicialização do Windows
   (`shell:startup`), ou via Agendador de Tarefas.

Cada etapa verifica se o app já está rodando antes de abrir de novo, então
o script é seguro de rodar mais de uma vez.
