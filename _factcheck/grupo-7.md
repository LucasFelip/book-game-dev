# Fact-check: grupo 7

Arquivos: parte-09/cap-63 a cap-68; interludio-2/decompondo-mundo-aberto.md; interludio-3/multiplayer-avancado.md.

| arquivo:linha | afirmação (curta) | veredito | fonte (URL) | mudança feita |
|---|---|---|---|---|
| parte-09/cap-63-client-server.md:101 | Rollback popularizado pelo GGPO; palestras GDC de estúdios de luta | OK | https://gdcvault.com/play/1025021 | — |
| parte-09/cap-63-client-server.md:131 | Tim Sweeney, "Unreal Networking Architecture" (1999), "cliente/servidor generalizado", servidor autoritativo | OK | https://www.zx.net.nz/mirror/unreal.epicgames.com/Network.htm | — |
| parte-09/cap-63-client-server.md:775 | Para ir além: "Unreal Networking Architecture", Tim Sweeney | OK | https://www.zx.net.nz/mirror/unreal.epicgames.com/Network.htm | — |
| parte-09/cap-63-client-server.md:778 | Para ir além: "8 Frames in 16ms: Rollback Networking in Mortal Kombat and Injustice 2", Michael Stallone (GDC Vault) | OK | https://gdcvault.com/play/1025021 | — |
| parte-09/cap-64-authority.md:215 | David Aldridge (Bungie), GDC 2011, "I Shot You First: Networking the Gameplay of Halo: Reach" | OK | https://www.gamedeveloper.com/business/gdc-vault-adds-free-crawford-i-halo-reach-i-maxis-lectures | — |
| parte-09/cap-64-authority.md:850 | Para ir além: mesma palestra (GDC 2011) | OK | idem | — |
| parte-09/cap-68-latency.md:858 | Para ir além: mesma palestra (GDC 2011) | OK | idem | — |
| parte-09/cap-67-prediction.md:210 | Timothy Ford (Blizzard), GDC 2017, "Overwatch Gameplay Architecture and Netcode"; ECS e predição | OK | https://gdcvault.com/play/1024001 | — |
| parte-09/cap-66-rpc.md:860; cap-67:980 | Para ir além: mesma palestra (GDC 2017) | OK | idem | — |
| parte-09/cap-68-latency.md:195 | Respawn publicou texto técnico sobre servidores de Apex (20 Hz) "em 2019" | CORRIGIDO | https://www.ea.com/games/apex-legends/news/servers-netcode-developer-deep-dive ; https://dotesports.com/apex-legends/news/respawn-addresses-netcode-servers-not-upgrading-apex-tick-rate-soon | "Em 2019" -> "Em 2021" (post "What Makes Apex Tick", abr/2021) |
| parte-09/cap-68-latency.md:94 | Valve, Source Multiplayer Networking: interpolação padrão de 100 ms | OK | https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking (403 para robôs; confirmado por citações em buscas) | — |
| parte-09/cap-68-latency.md:128 | Fórmula "tempo do servidor − latência do pacote − interpolação de visão do cliente" | OK | idem; https://developer.valvesoftware.com/wiki/Lag_Compensation | — |
| parte-09/cap-68-latency.md:187,255 | Source: servidor move jogadores ao passado e restaura; artigo de Yahn Bernier | OK | idem | — |
| parte-09/cap-68-latency.md:854 | Para ir além: Yahn Bernier, "Latency Compensating Methods..." (Valve, 2001) | OK | https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization (Proc. GDC 2001) | — |
| parte-09/cap-65-replication.md:186,249 | Replication Graph feito para Fortnite BR; 100 jogadores, dezenas de milhares de atores (~50.000) | OK | https://dev.epicgames.com/documentation/en-us/unreal-engine/replication-graph-in-unreal-engine | — |
| parte-09/cap-66-rpc.md:162 | Marcação (*spot*) "desde os Battlefield da geração do Bad Company 2 e do BF3" | CORRIGIDO | https://battlefield.fandom.com/wiki/Commo_Rose (pista; spotting pelo minimapa no BF2, 3D spotting no BF2142) | Reescrito: "No Bad Company 2, no Battlefield 3 e no Battlefield 4 (a mecânica vem de antes, do Battlefield 2 e do 2142)" |
| interludio-3/multiplayer-avancado.md:149 | Activision, 2024: texto técnico sobre matchmaking de CoD; conexão é o fator dominante | OK (ponteiro corrigido) | https://research.activision.com/publications/2024/04/callofduty-matchmaking-intel-ping | Fato OK; "(confira o texto no blog oficial de Call of Duty)" -> "(confira a série *Call of Duty Matchmaking* no site de pesquisa da Activision)" |
| interludio-3/multiplayer-avancado.md:454 | Para ir além: Michael Booth, *The AI Systems of Left 4 Dead* (2009) listado sob "GDC Vault" | CORRIGIDO | https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf ; https://www.gamedeveloper.com/pc/in-depth-stanford-conference-explores-the-state-of-ai | A palestra é da AIIDE 2009 (Stanford), slides publicados pela Valve; tirada do item "GDC Vault" e local corrigido |
| interludio-3/multiplayer-avancado.md:355 | AI Director de L4D (Valve, 2008), Michael Booth, *The AI Systems of Left 4 Dead* (2009), cooperativo para quatro | OK | idem | — |
| interludio-3/multiplayer-avancado.md:453 | Para ir além: Glenn Fiedler, *Networking for Physics Programmers* (GDC, GDC Vault) | OK | https://www.gdcvault.com/play/1022195 (GDC 2015; também GDC 2010) | — |
| parte-09/cap-68-latency.md:857 | Para ir além: Glenn Fiedler, Gaffer On Games, artigos de snapshot interpolation/estado | OK | https://gafferongames.com/categories/game-networking/ | — |
| parte-09/cap-64-authority.md:201 | Ricochet anunciado em 2021, com driver de kernel no PC e ferramentas no servidor | OK | https://www.callofduty.com/blog/2021/10/ricochet-anti-cheat-initiative-for-call-of-duty | — |
| parte-09/cap-64-authority.md:207 | BF4 usou PunkBuster e FairFight; FairFight = detecção no servidor, estatística | OK | https://www.pcgamer.com/battlefield-4-anti-cheating-measures-detailed ; https://mcvuk.com/development-news/beat-the-cheats-taking-the-fight-to-the-hackers/ | — |
| parte-09/cap-65-replication.md:241 | DICE publicou atualizações de netcode do BF4 que aumentaram a frequência de atualização | OK | https://mp1st.com/news/battlefield-4-high-frequency-network-update-hitting-pc-next-gen-consoles-heres-works | — |
| parte-09/cap-65-replication.md:239 | BF4 (DICE, 2013): 64 jogadores em PC/PS4/XB1, veículos, Levolution | OK | conhecimento consolidado | — |
| parte-09/cap-63-client-server.md:275 | CoD: MW (2019): servidores dedicados e crossplay anunciados | OK | https://gameinformer.com/2019/05/30/crossplay-will-be-supported-in-modern-warfare ; https://www.gamesradar.com/call-of-duty-modern-warfare-dedicated-servers-platforms | — |
| parte-09/cap-63-client-server.md:283 | BF4 permitia alugar servidores com regras próprias | OK | https://www.gamespot.com/articles/battlefield-4-players-can-now-rent-servers-unless-they-re-playing-on-xbox-one/1100-6419310/ | — |
| parte-09/cap-63-client-server.md:267 | eFootball roda em Unreal desde 2021 e tem partidas online | OK | https://www.dsogaming.com/news/efootball-2022-releases-on-september-30th-first-post-launch-update-detailed/ | — |
| parte-09/cap-63-client-server.md:263 | PES 2011 e FIFA 14 no PS2, versus local sem tela dividida | OK | observável; conhecimento consolidado (ambos lançados para PS2) | — |
| parte-09/cap-63..68 (Para ir além) | Gambetta, "Fast-Paced Multiplayer" partes I–IV (arquitetura, predição/reconciliação, interpolação, lag compensation); Glazer e Madhav, *Multiplayer Game Programming* | OK | https://www.gabrielgambetta.com/client-server-game-architecture.html | — |
| parte-09/cap-64-authority.md:197; cap-66:170; cap-68:201 | CoD: killcam, killstreaks/UAV (observável) | OK | observável jogando | — |
| parte-09/cap-65-replication.md:49 | ShooterGame (UE4) usava contador de disparos replicado (BurstCounter) | OK (não conferido na web) | — (limite de buscas atingido; o texto já tem "⚠️ confira") | — |
| parte-09/cap-65-replication.md:112 | UE 5.5 passou NetUpdateFrequency/MinNetUpdateFrequency para setters | OK (não conferido na web) | — (limite de buscas; docs da Epic recusaram conexão) | — |
| interludio-3/multiplayer-avancado.md:51 | Alvo de servidor dedicado exige engine compilada do código-fonte | OK (não conferido na web) | — (docs da Epic recusaram conexão; já tem "⚠️ confira") | — |
| interludio-3/multiplayer-avancado.md:147 | Elo, Glicko, TrueSkill (Microsoft Research, Xbox) | OK | conhecimento consolidado | — |
| interludio-3/multiplayer-avancado.md:210 | BF4 Levolution: arranha-céu de Siege of Shanghai; destruição desde Bad Company | OK | conhecimento consolidado | — |
| interludio-3/multiplayer-avancado.md:232 | GTA Online: sessões com dezenas de jogadores, progresso persistente, instâncias | OK | observável jogando (sessões de até 30) | — |
| interludio-3/multiplayer-avancado.md:133 | Lyra usa o plugin CommonUser sobre Online Services/OSS | OK | conhecimento consolidado | — |
| interludio-2/decompondo-mundo-aberto.md:66 | GTA SA (Rockstar, 2004), PS2 com 32 MB de RAM principal, três cidades; travessia cedo dá procurado alto | OK | conhecimento consolidado | — |
| interludio-2/decompondo-mundo-aberto.md:154 | SA: 1 min de jogo = 1 s real (dia em 24 min); arrombamentos só à noite | OK | observável jogando | — |
| interludio-2/decompondo-mundo-aberto.md:178 | SA seis estrelas; GTA V cinco estrelas que piscam fora de vista | OK | observável jogando | — |
| interludio-2/decompondo-mundo-aberto.md:219,279,281 | SA: marcadores com letra no radar, territórios de gangue, carro da garagem; GTA V: pontos de recomeço, veículo pessoal no pátio de apreensão | OK | observável jogando | — |
| interludio-2/decompondo-mundo-aberto.md:243 | GTA IV usa euphoria (NaturalMotion) | OK | conhecimento consolidado | — |
| interludio-2/decompondo-mundo-aberto.md:109,1245 | City Sample (de *The Matrix Awakens*) usa Mass para multidões e tráfego | OK | conhecimento consolidado | — |
| interludio-2/decompondo-mundo-aberto.md:317 | Data Layers: 5.3 trocou o gerenciador (UDataLayerManager) | OK (não conferido na web) | — (limite de buscas) | — |
| interludio-2/decompondo-mundo-aberto.md:1246,1247 | Nystrom, *Game Programming Patterns* (Object Pool, Update Method, Spatial Partition); Gregory, *Game Engine Architecture* | OK | https://gameprogrammingpatterns.com/contents.html | — |
| (todos) | Itens [INFERÊNCIA] conferidos: nenhum é apresentado como declaração de estúdio | OK | — | — |

Nota: a cota de WebSearch da sessão (compartilhada entre agentes) e o Firecrawl acabaram no fim do trabalho; os itens marcados "não conferido na web" ficaram como estavam (já têm aviso ⚠️ ou são de baixo risco).
