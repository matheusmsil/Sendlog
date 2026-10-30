# Próximos passos

Onde o Sendlog parou e o que falta para chegar à App Store. Atualizado em 30/10/2026.

## Onde estamos

- O app está pronto para publicação. A versão da loja (Release) compila para iPhone, mas **ainda não foi testada num iPhone real**.
- Branch: `sendlog-app`. Tudo está commitado, inclusive as mudanças de 30/10: backup no iCloud, remoção da recuperação e do programa do treinador, tela de Ajustes, site e kit da App Store.
- Tudo foi enviado ao GitHub, e o `main` está igual ao `sendlog-app`.

O passo a passo detalhado da publicação está em [app-store/README.md](app-store/README.md).

## Checklist

### 1. Git e GitHub
- [x] Commitar as mudanças pendentes.
- [x] Liberar o acesso ao GitHub (a chave SSH já está cadastrada; ela tem senha).
- [x] Fazer push do branch `sendlog-app`.
- [x] Juntar o `sendlog-app` ao `main` (necessário para o GitHub Pages).

### 2. Conta Apple
- [ ] Entrar no **Apple Developer Program** (US$ 99/ano).
- [ ] No Xcode, ir no target Sendlog › Signing & Capabilities › **Team** e escolher a equipe paga.
- [ ] Em Build Settings, mudar `SENDLOG_ICLOUD` para **YES** em **Debug** (Release já está YES).

### 3. Testar no iPhone
- [ ] Rodar no iPhone pelo Xcode, logado no iCloud.
- [ ] Testar:
  - criar e editar treinos e planos
  - "Treino de hoje"
  - importar do Apple Watch
  - vídeos
  - a tela de Ajustes
- [ ] Recriar os seus planos (o programa do treinador saiu do app) e colar os links de vídeo que quiser.

### 4. iCloud (CloudKit)
- [ ] Registrar pelo menos um treino com bloco de escalada, exercício de força e mobilidade, para criar o esquema.
- [ ] No **CloudKit Console** (Signing & Capabilities › iCloud › CloudKit Console), ir em **Deploy Schema Changes** para Production.

### 5. Site (suporte e privacidade)
- [ ] No GitHub, ir em Settings › Pages › Source: **GitHub Actions**. O `main` já tem a pasta `site/`.
- [ ] Depois, em **Actions › Publish site**, tocar em **Run workflow** (ou **Re-run**, se a primeira execução tiver falhado por o Pages ainda não estar ativado).
- [ ] Conferir se as páginas abrem:
  - https://matheusmsil.github.io/Sendlog/
  - https://matheusmsil.github.io/Sendlog/privacidade/
- [ ] Se o repositório for privado, deixá-lo público ou hospedar a pasta `site/` em outro lugar. Nesse caso, atualizar os links em `Sendlog/Views/SettingsView.swift` (`AppLinks`).

### 6. App Store Connect
- [ ] Criar o app: bundle `com.matheus.Sendlog`, idioma Português (Brasil).
- [ ] Ver se o nome "Sendlog" está livre.
- [ ] Colar os textos, as palavras-chave, as URLs e as notas para revisão de `app-store/README.md`.
- [ ] Subir as capturas de `app-store/screenshots/`.
- [ ] Privacidade: **"Não coletamos dados"**. Classificação etária: **4+**.

### 7. Enviar
- [ ] Xcode: **Any iOS Device** › Product › **Archive** › Distribute › App Store Connect.
- [ ] Testar no **TestFlight**, incluindo apagar e reinstalar o app para ver os dados voltarem do iCloud.
- [ ] Enviar para revisão.

## Lembretes

- **Conta gratuita:** o app instalado pelo Xcode expira em 7 dias.
- **Dados sincronizados:** depois de publicar, nunca renomeie nem apague campos sincronizados; só acrescente campos novos. A cada atualização, publique o esquema do CloudKit de novo.
- **Novas versões:** cada envio precisa de um número de Build maior.

## Ideias para depois

- Exportar e importar planos (para treinadores compartilharem programas).
- App para o Apple Watch, para marcar boulders e séries no pulso.
- Opção de kg ou lb.
- Registro específico de hangboard (régua, tempo de suspensão, pegada).
- Gráficos com graus Fontainebleau.
- Versão em inglês do app.
