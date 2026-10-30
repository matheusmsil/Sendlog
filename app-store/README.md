# Sendlog: publicação na App Store

Tudo o que vai no App Store Connect e os passos para levar este repositório até o app publicado.

## 1. Preparação (uma vez)

1. **Entre no Apple Developer Program** (US$ 99/ano) em developer.apple.com/programs, com a conta Apple que vai publicar o app.
2. **Troque a equipe no Xcode.** No target **Sendlog** › **Signing & Capabilities** › **Team**, escolha a equipe paga no lugar de "Personal Team".
3. **Ligue o iCloud no desenvolvimento.** Em **Build Settings**, procure `SENDLOG_ICLOUD` e mude **Debug** para `YES`. O Release já está em `YES`.
4. **Confira o iCloud.** Em **Signing & Capabilities** › **iCloud**, o contêiner `iCloud.com.matheus.Sendlog` deve estar marcado. Se estiver vermelho, toque em atualizar.
5. **Crie o esquema do CloudKit.** Rode o app no seu iPhone, logado no iCloud, e registre pelo menos um treino com bloco de escalada, exercício de força e bloco de mobilidade.
6. **Publique o esquema.** No CloudKit Console (botão em Signing & Capabilities › iCloud), abra o contêiner, vá em **Schema** e toque em **Deploy Schema Changes…** para Production. Sem isso, a sincronização não funciona na versão da App Store.
7. **Publique as páginas de suporte e privacidade.**
   1. Junte o branch `sendlog-app` ao `main` e faça push.
   2. No GitHub, vá em **Settings** › **Pages** › **Source: GitHub Actions**. O fluxo `.github/workflows/pages.yml` publica a pasta `site/`.
   3. Confira se as duas páginas abrem:
      - https://matheusmsil.github.io/Sendlog/
      - https://matheusmsil.github.io/Sendlog/privacidade/

   GitHub Pages em repositório privado exige plano pago do GitHub. Se o repositório for privado, deixe-o público ou hospede a pasta `site/` em outro lugar. Nesse caso, atualize os links em `Sendlog/Views/SettingsView.swift` (`AppLinks`).
8. **Crie o app.** No App Store Connect › **Apps** › **+** › **Novo app**, escolha:
   - plataforma iOS
   - nome: veja abaixo
   - idioma principal: **Português (Brasil)**
   - Bundle ID: `com.matheus.Sendlog`
   - SKU: `sendlog`

## 2. Enviar uma versão

1. No Xcode, escolha o destino **Any iOS Device (arm64)** e vá em **Product › Archive**.
2. No Organizer, vá em **Distribute App › App Store Connect › Upload**.
3. Teste no **TestFlight** no seu iPhone antes de enviar para revisão:
   - registrar e editar treinos e planos
   - "Treino de hoje"
   - importar do Apple Watch
   - vídeos
   - iCloud: apague o app, instale de novo e espere os dados voltarem
4. Cada envio precisa de um número de **Build** maior (`CURRENT_PROJECT_VERSION`). A **Versão** (`MARKETING_VERSION`, hoje 1.0) sobe a cada lançamento público.

## 3. Página na App Store

| Campo | Valor |
|---|---|
| Nome (30) | Sendlog: Treino de Escalada |
| Subtítulo (30) | Boulder, força e evolução |
| Categoria principal | Saúde e fitness |
| Categoria secundária | Esportes |
| Palavras-chave (100) | `escalada,boulder,treino,musculação,hangboard,grau,ginásio,força,academia,flash,mobilidade,climbing` |
| URL de suporte | https://matheusmsil.github.io/Sendlog/ |
| URL da política de privacidade | https://matheusmsil.github.io/Sendlog/privacidade/ |
| Copyright | 2026 Matheus Monteiro Silveira |
| Preço | Você escolhe (ex.: gratuito) |

Se o nome "Sendlog" já estiver em uso, o App Store Connect não deixa usar. Nesse caso, ajuste o nome.

**Texto promocional (170)**

> Monte seus planos de treino uma vez e comece o treino do dia com um toque. Acompanhe sua pirâmide de graus, carga de treino e força relativa.

**Descrição**

> O Sendlog é o diário de treino feito para escaladores. Registre seus treinos de boulder, musculação, mobilidade e ativação em poucos toques e veja sua evolução com painéis pensados para quem quer subir de grau.
>
> TREINOS DE ESCALADA
> • Blocos de circuito, repetições, boulder máximo e escalada livre
> • Variações como hover hands, um pé só e pé silencioso
> • Grau (escala V ou Fontainebleau), entradas, flash e boulders mandados
> • Inclinação (slab, vertical, overhang, roof) e tipo de agarra (crimp, sloper, pinch, pocket…)
>
> MUSCULAÇÃO, MOBILIDADE E ATIVAÇÃO
> • Exercícios com séries, repetições e cargas
> • Blocos de mobilidade e ativação em qualquer treino
> • Prescrição do treinador e link de vídeo para cada exercício
>
> PLANOS
> • Escreva uma vez os treinos que seu treinador manda
> • Escolha os dias da semana e comece o "Treino de hoje" com um toque
> • Notas do treinador sempre à mão durante o treino
>
> PROGRESSO
> • Maior grau, grau de flash, grau consolidado e aproveitamento
> • Pirâmide de graus com dicas para consolidar antes de subir
> • Pontos fortes e fracos por inclinação e tipo de agarra
> • Acompanhamento de projetos
> • Carga de treino (PSE × minutos) e relação carga aguda : crônica
> • Força relativa no hangboard e na barra fixa com carga
>
> APPLE WATCH E APP SAÚDE
> • Importe treinos do Apple Watch com duração, calorias e frequência cardíaca
> • Os dados do app Saúde ficam só no seu iPhone
>
> BACKUP NO ICLOUD
> • Seus treinos e planos ficam no iCloud da sua conta Apple: troque de celular sem perder nada
> • Sem cadastro, sem anúncios, sem rastreamento
>
> O Sendlog não é um dispositivo médico. As análises são referências gerais de treino.

**Capturas de tela (iPhone 6,9", 1320 × 2868):** estão em `app-store/screenshots/`, nesta ordem:
1. Treinos
2. Treino de escalada
3. Planos
4. Escalada
5. Pirâmide
6. Força
7. Carga

Elas usam os dados de exemplo do app. Para gerar de novo, rode no simulador iPhone 17 Pro Max com `-seedSampleData`.

## 4. Privacidade do app ("rótulo nutricional")

- **Coleta de dados:** responda **"Não, não coletamos dados neste app."** Os treinos ficam no aparelho e no iCloud privado do usuário, e os dados do app Saúde ficam só no aparelho. Nada chega ao desenvolvedor, e não há SDKs, análises nem anúncios.
- **Manifesto de privacidade:** `Sendlog/PrivacyInfo.xcprivacy` já está no app. Ele declara sem rastreamento, sem dados coletados e o motivo `CA92.1` para `UserDefaults`.

## 5. Classificação etária

Responda **Nenhum** em tudo. O app não tem navegador próprio (outros links abrem no Safari) nem conteúdo compartilhado entre usuários. Classificação esperada: **4+**.

## 6. Notas para a revisão da Apple

Copie o texto abaixo no campo de notas. Deixe os campos de login em branco, porque o app não tem conta.

> O Sendlog não tem login: os dados ficam no iPhone e no iCloud privado do usuário (CloudKit). Para testar: na aba Planos toque em + para criar um plano, ou na aba Treinos toque em + › Treino de escalada. Os painéis da aba Progresso aparecem depois de registrar alguns treinos com grau nos boulders.
>
> HealthKit: o app só lê dados (treinos, frequência cardíaca, energia ativa e peso corporal). É usado em Treinos › + › Importar do Apple Watch, no botão "Vincular treino do Apple Watch" dentro de um treino e no botão do app Saúde ao lado do peso corporal (Progresso › Força). Os dados do HealthKit ficam somente no aparelho e não vão para o iCloud.
>
> Sendlog has no sign-in. Data is stored on device and in the user's private iCloud database. HealthKit is read-only (workouts, heart rate, active energy, body mass), is used to link Apple Watch workouts to sessions and to compute relative strength, and HealthKit data is never stored in iCloud.

## 7. Conformidade de exportação

`ITSAppUsesNonExemptEncryption` já está como `NO` em `Sendlog-Info.plist`, então o App Store Connect não pergunta sobre criptografia.

## Depois de publicado

- **Regras dos dados sincronizados.** Nunca renomeie nem apague campos dos modelos sincronizados (`TrainingSession`, blocos, boulders, séries, itens). Só acrescente campos novos, sempre com valor padrão. Antes de lançar cada atualização, publique de novo o esquema do CloudKit em Production.
- **Lançar uma atualização.** Aumente o Build, faça Archive, Upload e TestFlight, e só então envie para revisão.
