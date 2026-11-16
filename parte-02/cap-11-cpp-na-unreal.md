# Capítulo 11 — C++ na Unreal

## Objetivo

Ao final deste capítulo você deve conseguir:

- entender o **modelo de compilação** do C++ (headers, unidades de tradução, *forward declarations*) e como ele afeta tempo de build e organização de código;
- trabalhar com **valores, referências e ponteiros**, `const` e RAII com a fluência necessária para ler e escrever código de gameplay;
- separar os **dois mundos de memória** da Unreal: objetos gerenciados pelo garbage collector (`UObject`) e objetos com RAII e ponteiros inteligentes;
- usar o **sistema de reflexão** (`UCLASS`, `UPROPERTY`, `UFUNCTION`) e seus especificadores mais importantes;
- entender o **garbage collector** da Unreal e escolher corretamente entre `TObjectPtr`, ponteiro cru, `TWeakObjectPtr`, `TSoftObjectPtr` e `TSubclassOf`;
- usar contêineres e strings da Unreal (`TArray`, `TMap`, `TSet`, `FString`, `FName`, `FText`);
- tratar erros **sem exceções**: `check`, `ensure`, `IsValid`, `TOptional`;
- criar categorias de log, *console variables* e comandos de console para depurar o jogo.

---

## Contexto

Você é um programador Java experiente. Isso é uma vantagem grande e uma armadilha sutil. A vantagem: tipos, objetos, interfaces, coleções, genéricos, garbage collection, *profiling* — você já pensa nisso tudo. A armadilha: o C++ **parece** Java o bastante para que você escreva código que compila, roda e está profundamente errado.

Há duas camadas a aprender, e é importante não misturá-las:

1. **C++ moderno**, a linguagem — compilação, memória, valores, `const`, templates leves.
2. **O dialeto da Unreal** — `UObject`, reflexão, garbage collector próprio, contêineres próprios, macros, convenções. A Unreal usa C++ de um jeito particular, e boa parte do que você leria num livro de C++ padrão (exceções, `std::shared_ptr`, `std::string`, RTTI) **não** é usado em código de gameplay da engine.

Este capítulo não é um curso de C++. Ele cobre exatamente o que você precisa para o resto do livro, com ênfase nas diferenças em relação a Java e nas armadilhas que derrubam programadores experientes. Para o C++ padrão, a referência é **cppreference.com**; para o dialeto, a documentação da Unreal e — muito importante — **o próprio código-fonte da engine**, que vem junto com a instalação do launcher.

---

## 11.1 O modelo de compilação

Em Java, um `import` é **simbólico**: o compilador procura a classe pelo nome. Em C++, um `#include` é **textual**: o pré-processador literalmente copia o conteúdo do arquivo no lugar da diretiva, antes de compilar.

```text
JAVA                                   C++
────                                   ───
Door.java  (declaração + definição)    VGDoor.h    declaração: "o que existe"
                                       VGDoor.cpp  definição:  "como funciona"
import com.vigilia.Door;  (símbolo)    #include "VGDoor.h"  (cópia de texto)
```

Cada `.cpp`, depois de expandidos todos os seus includes, vira uma **unidade de tradução** compilada de forma independente. O *linker* junta as unidades no final. Consequências práticas:

- **Headers são compilados muitas vezes.** Se `VGCharacter.h` é incluído por 40 arquivos `.cpp`, ele é processado 40 vezes. Um header que inclui muitos outros headers deixa o build inteiro lento.
- **Mudar um header recompila todos que o incluem.** Mudar um `.cpp` recompila só ele. Por isso, **o que puder ficar no `.cpp`, fica no `.cpp`**.
- **Cada `#include` num header é um custo propagado.** Daí a técnica mais importante para manter builds rápidos: *forward declarations*.

### Forward declarations

Se um header só precisa **mencionar** um tipo por ponteiro ou referência — sem acessar seus membros —, ele não precisa incluir o header desse tipo. Basta declarar que o tipo existe:

```cpp
// VGFlickerComponent.h
class ULightComponent;   // forward declaration: "existe uma classe com este nome"

UPROPERTY(Transient)
TArray<TObjectPtr<ULightComponent>> Lights;   // ponteiro: o tamanho é conhecido sem saber o tipo
```

```cpp
// VGFlickerComponent.cpp
#include "Components/LightComponent.h"   // aqui sim: vamos chamar SetIntensity()
```

Você já viu isso no Capítulo 9 e no Capítulo 10 (`class UCameraComponent;`). A regra: **no header, forward-declare tudo que for possível; inclua no `.cpp`.**

### Convenções de include da Unreal

- **`#pragma once`** no topo de todo header (evita inclusão dupla).
- **O header correspondente primeiro** no `.cpp` (`#include "World/VGFlickerComponent.h"`), seguido dos demais. Isso garante que o header é autossuficiente.
- **O `*.generated.h` é sempre o último include** de um header com classes reflexivas.
- **Inclua o que você usa** (*include what you use*): não dependa de que um header "venha junto" de outro.

### Unity builds: o include que "funcionava"

Para acelerar a compilação, o UBT usa por padrão **unity builds**: junta vários `.cpp` num só arquivo gigante antes de compilar. Efeito colateral perigoso: um `.cpp` que esqueceu um include pode compilar porque **outro** `.cpp` do mesmo lote incluiu o header antes dele. O dia em que o agrupamento mudar (você adicionou um arquivo), o erro aparece "do nada", num arquivo que você nem tocou.

Para verificar se os seus includes estão corretos, de vez em quando compile com unity desligado (no `Vigilia.Build.cs`, `bUseUnity = false;` temporariamente, ou a opção equivalente do UBT). Não deixe desligado: o build fica mais lento.

---

## 11.2 Valores, referências e ponteiros

Em Java, **todo objeto é uma referência** e todo primitivo é um valor. Em C++, **qualquer tipo** pode ser usado como valor, referência ou ponteiro:

```cpp
FVector A(1.0, 2.0, 3.0);   // VALOR: o objeto vive aqui (na pilha, ou dentro do objeto que o contém)
FVector B = A;              // CÓPIA: B é outro vetor, independente de A
FVector& R = A;             // REFERÊNCIA: R é outro nome para A (não pode ser nula, não pode "mudar de alvo")
FVector* P = &A;            // PONTEIRO: guarda o endereço de A (pode ser nulo, pode apontar para outro)
```

Para o código de gameplay na Unreal, as regras práticas são:

| Tipo | Como passar e guardar | Por quê |
|---|---|---|
| Structs pequenas (`FVector`, `FRotator`, `FTransform`, `FColor`) | **Por valor** ou por `const&` | São "valores", como `record`s em Java; copiar é barato e seguro |
| Structs maiores, `FString`, contêineres | **`const&`** nos parâmetros; por valor quando você vai guardar uma cópia | Evitar cópias desnecessárias |
| `UObject`s (Actors, Components...) | **Sempre por ponteiro** (`AActor*`, `TObjectPtr<AActor>`) | São gerenciados pelo GC; nunca existem por valor |
| Parâmetros de saída | Referência não-`const` (`FHitResult& OutHit`) — convenção da Unreal: prefixo `Out` | Retornar múltiplos valores sem alocar |

```cpp
// Leitura: const& — "não vou copiar, não vou modificar".
float ComputeDamage(const FVGDamageInfo& Info, float Distance);

// Saída: referência não-const com prefixo Out — convenção da Unreal.
bool TraceInteractable(FHitResult& OutHit) const;
```

### `const`

`const` é muito mais presente em C++ do que `final` em Java, e é uma ferramenta de design:

```cpp
float GetChargeRatio() const;            // método const: promete não alterar o objeto
void Drain(float Amount);                // não-const: altera
const FVector& GetTarget() const;        // devolve referência que não pode ser usada para alterar
```

Um método `const` só pode chamar outros métodos `const` do mesmo objeto. Isso torna explícito, no tipo, quais operações são consultas e quais são comandos — a separação CQS que você conhece, verificada pelo compilador. Nos componentes do livro, todos os *getters* são `const`.

> 🌉 **Ponte:** structs da Unreal como `FVector` se comportam como **value objects** de DDD — imutáveis por convenção de uso, comparados por valor, copiados livremente.
>
> 🧱 **Onde a ponte cai:** em C++, a cópia é o comportamento **padrão** de atribuição. Em Java, `a = b` com objetos compartilha a referência; em C++, `FVector a = b` copia. Isso evita uma classe inteira de bugs de aliasing — e cria outra: modificar a cópia achando que modificou o original.

---

## 11.3 Memória: dois mundos

Em C++ padrão, a memória é gerenciada por **RAII** (*Resource Acquisition Is Initialization*): um objeto adquire recursos no construtor e os libera no destrutor, que é chamado **deterministicamente** quando o objeto sai de escopo. Ponteiros inteligentes (`std::unique_ptr`, `std::shared_ptr`) aplicam RAII à memória no heap.

A Unreal tem **dois mundos de memória**, e não misturá-los é essencial:

```text
┌──────────────────────────────────────┬──────────────────────────────────────┐
│ MUNDO 1 — UObject                    │ MUNDO 2 — Tudo o mais                │
│ (Actors, Components, assets, ...)    │ (structs F, classes C++ comuns)      │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ Criado com NewObject,                │ Criado por valor, ou com             │
│ CreateDefaultSubobject, SpawnActor   │ MakeUnique / MakeShared              │
│                                      │                                      │
│ NUNCA new / delete                   │ RAII: destrutor libera               │
│                                      │                                      │
│ Liberado pelo garbage collector      │ TUniquePtr, TSharedPtr, TSharedRef,  │
│ quando inalcançável                  │ TWeakPtr (equivalentes aos std::)    │
│                                      │                                      │
│ Referências: TObjectPtr (UPROPERTY), │ Referências: ponteiros inteligentes  │
│ TWeakObjectPtr, TSoftObjectPtr       │ da Unreal; NUNCA para UObjects       │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

Duas regras que você não deve violar:

1. **Nunca use `new`/`delete` com `UObject`s.** Nunca. A engine precisa registrar o objeto no sistema de objetos e no GC.
2. **Nunca use `TSharedPtr`/`TUniquePtr` (nem os `std::`) para `UObject`s.** O GC e o contador de referências brigariam pela posse do objeto.

Na prática, quase todo o código de gameplay vive no Mundo 1. O Mundo 2 aparece em structs de dados (`FVGTimeDilationRequest` do Capítulo 6) e em sistemas mais baixo nível. Quando precisar de um objeto C++ comum alocado dinamicamente, use `TUniquePtr` (posse única) por padrão, e `TSharedPtr` só quando a posse for realmente compartilhada.

A Unreal usa os seus próprios ponteiros inteligentes e contêineres em vez dos da biblioteca padrão por razões históricas, de portabilidade entre plataformas e de integração com a engine. Em código de gameplay, siga a convenção da engine: `TArray`, não `std::vector`; `FString`, não `std::string`; `TUniquePtr`, não `std::unique_ptr`.

---

## 11.4 Reflexão e o Unreal Header Tool

C++ não tem reflexão em tempo de execução comparável à de Java. A Unreal **adiciona** reflexão com macros que o **Unreal Header Tool** (UHT) lê antes da compilação, gerando código C++ (Capítulo 7).

```cpp
UCLASS(Blueprintable)                              // a classe é conhecida pela engine
class VIGILIA_API AVGSpawner : public AActor
{
    GENERATED_BODY()                               // insere o código gerado pelo UHT

public:
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Spawner")
    void ResetSpawner();                           // a função é conhecida pela engine

protected:
    UPROPERTY(EditAnywhere, Category = "Vigilia|Spawner", meta = (ClampMin = "1"))
    int32 MaxAlive = 5;                            // a propriedade é conhecida pela engine
};
```

O que a reflexão habilita — e por que ela está no centro de tudo:

| Capacidade | Depende de |
|---|---|
| Aparecer e ser editado no editor (Details) | `UPROPERTY` com `Edit*`/`Visible*` |
| Ser usado em Blueprint | `UCLASS(Blueprintable)`, `UPROPERTY(Blueprint*)`, `UFUNCTION(Blueprint*)` |
| Ser salvo em assets e níveis | `UPROPERTY` (exceto `Transient`) |
| Ser rastreado pelo garbage collector | `UPROPERTY` em ponteiros para `UObject` |
| Ser replicado em rede | `UPROPERTY(Replicated)`, `UFUNCTION(Server/Client/NetMulticast)` (Parte IX) |
| Ser lido de arquivos de configuração | `UCLASS(Config)` + `UPROPERTY(Config)` |
| Ser chamado como comando de console | `UFUNCTION(Exec)` (seção 11.11) |
| Ser usado como handler de delegate dinâmico | `UFUNCTION()` (Capítulo 8, `HandleSpawnedDestroyed`) |

> 🌉 **Ponte:** é análogo a anotações processadas em tempo de compilação (como Lombok, MapStruct ou os processadores do Dagger): metadados declarativos que geram código.
>
> 🧱 **Onde a ponte cai:** em Java, reflexão em runtime existe independentemente das anotações. Na Unreal, **sem a macro, a engine não sabe que o membro existe** — não há fallback. E a reflexão não é um "extra" de conveniência: o garbage collector **depende** dela (seção 11.5).

### Especificadores de `UPROPERTY` mais usados

| Especificador | Efeito |
|---|---|
| `EditAnywhere` | Editável no Blueprint (padrões) e em instâncias no nível |
| `EditDefaultsOnly` | Editável só nos padrões (Blueprint/CDO), não por instância |
| `EditInstanceOnly` | Editável só em instâncias no nível (Capítulo 2, `TickAfter`) |
| `VisibleAnywhere` / `VisibleDefaultsOnly` / `VisibleInstanceOnly` | Só leitura no editor |
| `BlueprintReadOnly` / `BlueprintReadWrite` | Acesso em Blueprint |
| `Category = "A\|B"` | Agrupamento no Details e na paleta de Blueprint |
| `meta = (ClampMin, ClampMax, UIMin, UIMax)` | Limites de edição |
| `meta = (EditCondition = "bUseX")` | Só editável se outra propriedade for verdadeira |
| `meta = (AllowPrivateAccess = "true")` | Expor ao Blueprint um membro `private` |
| `Transient` | Não é salvo (preenchido em runtime) |
| `Config` | Valor lido de arquivo `.ini` |

A escolha entre `EditAnywhere`, `EditDefaultsOnly` e `EditInstanceOnly` é uma decisão de **design de ferramenta**: quem deve poder mudar este valor, e em que nível? A velocidade de caminhada da jogadora deve ser `EditDefaultsOnly` (é da classe, não de uma instância). A porta que um painel elétrico destranca é `EditInstanceOnly` (cada painel aponta para a sua porta). O padrão `EditAnywhere` usado em exemplos é conveniente, mas pense na escolha.

### Especificadores de `UFUNCTION` mais usados

| Especificador | Efeito |
|---|---|
| `BlueprintCallable` | Pode ser chamada de Blueprint (nó com pino de execução) |
| `BlueprintPure` | Chamada de Blueprint sem pino de execução (consulta sem efeitos colaterais; `const` não é exigido, mas uma função `const` com `BlueprintCallable` vira pura automaticamente — Capítulo 13) |
| `BlueprintImplementableEvent` | Declarada em C++, implementada só em Blueprint (Capítulo 13) |
| `BlueprintNativeEvent` | Implementação padrão em C++, sobrescrevível em Blueprint (Capítulo 13) |
| `Exec` | Pode ser chamada pelo console (em classes específicas — seção 11.11) |
| `Server`, `Client`, `NetMulticast` | RPCs de rede (Capítulo 66) |

---

## 11.5 O garbage collector da Unreal

O GC da Unreal é um **mark-and-sweep**: periodicamente, ele parte de um conjunto de **raízes** (o mundo, objetos marcados como raiz, referências registradas), percorre todas as referências a `UObject`s que ele **consegue enxergar**, marca os alcançáveis e coleta os demais.

A frase em negrito é a chave: **o GC só enxerga referências que passam pelo sistema de reflexão.** Um ponteiro para `UObject` guardado num membro **sem `UPROPERTY`** é invisível para o GC.

```cpp
UCLASS()
class AVGExample : public AActor
{
    GENERATED_BODY()

    UPROPERTY()
    TObjectPtr<UVGBatteryComponent> SafeBattery;   // ✓ o GC enxerga: mantém vivo e sabe que existe

    UVGBatteryComponent* DangerousBattery;          // ✗ o GC NÃO enxerga
};
```

O que pode acontecer com `DangerousBattery`: o objeto apontado deixa de ser referenciado por qualquer outro caminho visível; o GC o coleta; o ponteiro continua apontando para a memória antiga. Na próxima vez que você o usar — às vezes segundos ou minutos depois, quando o GC rodar —, **crash**, ou pior, corrupção silenciosa. É o bug clássico de quem chega de Java, onde "ter uma referência" sempre basta para manter o objeto vivo.

> **Regra de ouro:** todo ponteiro para `UObject` que é **membro** de uma classe ou struct reflexiva deve ser `UPROPERTY()` — mesmo que você não queira expô-lo ao editor. `UPROPERTY()` sem especificadores é exatamente "torne isto visível ao GC". (Variáveis locais dentro de uma função não precisam: o GC não roda no meio da execução da sua função no game thread.)

E se o membro estiver numa classe que **não** é `UObject` (uma classe C++ comum)? Então não há `UPROPERTY` possível. As alternativas são `TStrongObjectPtr` (mantém vivo), herdar de `FGCObject` e reportar referências manualmente, ou — mais comum — guardar um `TWeakObjectPtr` e verificar validade.

### Os tipos de referência a `UObject`

| Tipo | Mantém vivo? | Fica nulo quando o objeto é coletado? | Uso |
|---|:-:|:-:|---|
| `TObjectPtr<T>` (como `UPROPERTY`) | **Sim** | Sim (o GC limpa referências a objetos destruídos) | **Padrão do UE5 para membros** |
| `T*` cru como `UPROPERTY` | Sim | Sim | Equivalente, estilo antigo; aceito, mas prefira `TObjectPtr` em membros |
| `T*` cru **sem** `UPROPERTY` | **Não** | **Não** — ponteiro pendente | Só variáveis locais e parâmetros |
| `TWeakObjectPtr<T>` | Não | Sim | Observar sem possuir: alvo da IA, ator que pode sumir |
| `TSoftObjectPtr<T>` / `TSoftClassPtr<T>` | Não (é um **caminho**) | — | Asset carregado sob demanda (Capítulo 7, referências fracas) |
| `TSubclassOf<T>` | (referência de classe) | — | Escolher uma classe no editor (Capítulo 8) |

`TObjectPtr` foi introduzido no UE5. Em builds de editor, ele adiciona rastreamento de acesso e suporte a carregamento tardio; em builds de jogo, ele se comporta como um ponteiro cru. O estilo recomendado é usá-lo em **membros** `UPROPERTY` e continuar usando `T*` em parâmetros e variáveis locais.

### Destruição e validade

Destruir um ator (`Destroy()`) **não** libera a memória imediatamente: o objeto é marcado como lixo e removido na próxima coleta. Entre um momento e outro, ponteiros para ele ainda são "não nulos" mas apontam para um objeto inválido. Por isso:

```cpp
if (IsValid(Target))   // não nulo E não marcado para destruição
{
    Target->DoSomething();
}
```

Use `IsValid()` em vez de `if (Target)` sempre que o objeto puder ter sido destruído por outro sistema.

### O GC custa frames

A coleta percorre os objetos vivos e, em projetos grandes, pode levar vários milissegundos — aparecendo como **hitches** periódicos (Capítulo 3). A engine tem opções para espalhar e ajustar a coleta (coleta incremental, agrupamento de objetos, intervalo entre coletas). O Capítulo 58 discute como medir; o hábito a criar desde já é **não criar e destruir milhares de `UObject`s por segundo** sem necessidade (projéteis, eventos, mensagens) — o que é mais um motivo para o *pooling* do Capítulo 32 e para usar structs (Mundo 2) em dados efêmeros.

> 🌉 **Ponte:** você conhece GC da JVM — *stop-the-world*, gerações, pausas.
>
> 🧱 **Onde a ponte cai:** a JVM descobre referências sozinha, percorrendo o heap; a Unreal só descobre o que a reflexão declara. E, enquanto uma pausa de 50 ms numa API é um p99 ruim, num jogo é uma travada que o jogador vê.

---

## 11.6 Contêineres e strings

### Contêineres

| Unreal | Equivalente | Notas |
|---|---|---|
| `TArray<T>` | `ArrayList<T>` / `std::vector` | O contêiner padrão. Contíguo na memória (Capítulo 6). |
| `TMap<K, V>` | `HashMap<K, V>` | Ordem de iteração não deve ser considerada estável (Capítulo 3, determinismo) |
| `TSet<T>` | `HashSet<T>` | |

Operações que diferem de Java:

```cpp
TArray<AActor*> Targets;
Targets.Reserve(16);                   // pré-aloca: evita realocações num laço
Targets.Add(Actor);                    // copia/move o elemento para o fim
Targets.Emplace(...);                  // constrói no lugar (para structs)

Targets.Remove(Actor);                 // remove TODAS as ocorrências, preservando a ordem (O(n))
Targets.RemoveSwap(Actor);             // remove trocando com o último: rápido, não preserva ordem
Targets.RemoveAll([](AActor* A) { return !IsValid(A); });   // remove por predicado

for (AActor* Target : Targets) { ... } // iteração por range: NÃO remova elementos aqui dentro
```

Remover elementos de um `TArray` enquanto se itera sobre ele com *range-for* é comportamento indefinido — o mesmo problema do `ConcurrentModificationException` do Java, mas **sem** a exceção para avisar. Use `RemoveAll`, ou itere de trás para frente com índice.

### Três tipos de texto

A Unreal tem **três** tipos de string, com papéis diferentes. Usar o errado é um dos erros mais comuns de iniciante:

| Tipo | O que é | Use para |
|---|---|---|
| **`FString`** | Texto mutável, como `StringBuilder`/`String` | Manipulação de texto, logs, caminhos, depuração |
| **`FName`** | Identificador imutável, *interned*, comparação barata, **não diferencia maiúsculas/minúsculas** | Nomes de sockets, bones, tags, chaves de dados, "razões" (`Reason` do Capítulo 6) |
| **`FText`** | Texto **exibido ao jogador**, localizável | Tudo que aparece na UI: legendas, documentos, prompts de interação |

```cpp
const FName SocketName = TEXT("hand_r");                              // identificador
const FString DebugLine = FString::Printf(TEXT("Carga: %.1f"), Charge); // texto técnico
const FText Prompt = NSLOCTEXT("Vigilia", "OpenDoor", "Abrir porta");   // texto do jogador
```

> 🌉 **Ponte:** `FName` é como uma string *interned* (ou um enum de identificadores criado em runtime); `FText` é como uma chave de *message bundle* de i18n que resolve para o idioma atual.

A regra para a Vigília: **qualquer texto que o jogador lê é `FText`** desde o primeiro dia. Documentos, legendas e prompts escritos como `FString` precisam ser reescritos quando o jogo for localizado — e a Vigília, escrita em português, é uma candidata natural a ter uma versão em inglês.

E a macro `TEXT("...")`: strings literais na Unreal são de caracteres largos (`TCHAR`), e a macro garante o tipo correto de literal em todas as plataformas. Use-a em todo literal.

---

## 11.7 Casting

Para converter um ponteiro de `UObject` para um tipo mais específico, use **`Cast<T>`**:

```cpp
if (AVGCharacter* Player = Cast<AVGCharacter>(OtherActor))
{
    // OtherActor é (ou herda de) AVGCharacter
}
```

`Cast<T>` usa o sistema de reflexão (não o RTTI do C++, que a Unreal normalmente não habilita), é rápido e devolve `nullptr` se o tipo não corresponder. Variações: `CastChecked<T>` (falha com erro se o tipo não bater — use quando um tipo errado é um bug) e `IsA<T>()` (só verifica).

O idioma `if (T* X = Cast<T>(Y))` é tão comum na Unreal que vale fixar: declara, converte e testa numa linha só.

Uma observação de arquitetura: **cadeias de `Cast` são um cheiro de código.** "Se for porta, faça X; se for gaveta, faça Y; se for painel, faça Z" é o `if/else` por tipo que interfaces resolvem (Capítulo 19). O `Cast` é ótimo para perguntas pontuais ("este ator que entrou no trigger é a jogadora?"), ruim como mecanismo de polimorfismo.

---

## 11.8 Erros sem exceções

Esta é uma das maiores diferenças culturais em relação a Java: **código da Unreal não usa exceções.** Elas são, em geral, desabilitadas na compilação. Não há `try/catch` para erros de gameplay.

O tratamento de erros se divide em três categorias:

**1. Situações esperadas** (o ator não tem o componente, o trace não acertou nada, o spawn falhou): **retorno e verificação**.

```cpp
UVGBatteryComponent* Battery = Owner->FindComponentByClass<UVGBatteryComponent>();
if (!Battery)
{
    UE_LOG(LogVigilia, Warning, TEXT("%s sem bateria."), *Owner->GetName());
    return;
}

TOptional<FVector> FindSafeSpawnPoint();   // TOptional: "talvez não haja valor"
```

**2. Bugs que não devem derrubar o jogo** (uma invariante foi violada, mas dá para continuar): **`ensure`**.

```cpp
if (!ensureMsgf(MaxCharge > 0.0f, TEXT("MaxCharge inválido em %s"), *GetName()))
{
    return;
}
```

`ensure` avalia a condição; se ela falhar, registra um erro **com call stack** no log (uma vez por execução, por padrão), interrompe no depurador se houver um anexado, e **continua**. É a ferramenta certa para "isso não deveria acontecer, mas se acontecer quero saber, sem perder a sessão de teste".

**3. Bugs fatais** (continuar corromperia o estado): **`check`**.

```cpp
check(World != nullptr);
checkf(Index >= 0, TEXT("Índice negativo: %d"), Index);
```

`check` derruba o programa com um *assert* em builds de desenvolvimento. Em builds **Shipping**, `check` é, por padrão, compilado como nada — portanto **nunca coloque efeitos colaterais dentro de um `check`** (use `verify`, que mantém a expressão em Shipping).

| Situação | Ferramenta |
|---|---|
| Esperada (dado de conteúdo pode faltar, consulta pode falhar) | `if` + retorno + log de aviso; `TOptional`; `bool` + parâmetro `Out` |
| Bug recuperável | `ensure` / `ensureMsgf` |
| Bug irrecuperável | `check` / `checkf` |

> 🌉 **Ponte:** `ensure` é o equivalente a registrar um erro no Sentry/Application Insights e seguir em frente; `check` é o `IllegalStateException` que você deixa subir e derrubar a requisição.
>
> 🧱 **Onde a ponte cai:** em backend, derrubar uma requisição custa uma requisição. Num jogo, `check` derruba **o editor inteiro** com o nível não salvo, ou o jogo do jogador. Por isso a cultura da Unreal é usar `ensure` generosamente e `check` com parcimônia.

---

## 11.9 Logging

Até aqui, os capítulos usaram categorias de log estáticas por arquivo (`DEFINE_LOG_CATEGORY_STATIC`) e, em alguns lugares, `LogTemp`. Agora o projeto ganha uma categoria própria, compartilhada:

```cpp
// Source/Vigilia/Core/VGLog.h
#pragma once

#include "CoreMinimal.h"

DECLARE_LOG_CATEGORY_EXTERN(LogVigilia, Log, All);
```

```cpp
// Source/Vigilia/Core/VGLog.cpp
#include "Core/VGLog.h"

DEFINE_LOG_CATEGORY(LogVigilia);
```

Uso:

```cpp
#include "Core/VGLog.h"

UE_LOG(LogVigilia, Warning, TEXT("%s: ActorClass não configurada; spawner inativo."), *GetName());
```

Pontos importantes:

- **Verbosidade:** `Fatal`, `Error`, `Warning`, `Display`, `Log`, `Verbose`, `VeryVerbose`. A categoria declara a verbosidade padrão e a máxima compilada.
- **`*` antes de `FString`** (`*GetName()`): `UE_LOG` usa formatação no estilo `printf`, que espera um ponteiro de caracteres; o operador `*` de `FString` o fornece. Esquecer o `*` é um erro de compilação comum (ou, pior, um log com lixo).
- **Logging estruturado:** versões recentes do UE5 oferecem `UE_LOGFMT` (header `Logging/StructuredLog.h`), com parâmetros nomeados no estilo `"Spawned {Name}"`. Se a sua versão tiver, é uma alternativa mais legível; o livro usa `UE_LOG` por compatibilidade.
- **Na tela:** `GEngine->AddOnScreenDebugMessage(...)` mostra mensagens no viewport — útil para depuração rápida, nunca para comunicação com o jogador.

🔁 **Pequena refatoração:** substitua os `LogTemp` dos Capítulos 8 e 9 (`AVGSpawner`, `UVGFlickerComponent`) por `LogVigilia`. As categorias estáticas dos atores de diagnóstico (`LogVGTick`, `LogVGLifecycle`) podem continuar: elas existem justamente para ser filtradas isoladamente.

---

## 11.10 Lambdas e funções como valores

Lambdas em C++ são parecidas com as de Java, com uma diferença fundamental: **você declara explicitamente o que é capturado e como**.

```cpp
const float Threshold = 0.2f;
Targets.RemoveAll([Threshold](const AActor* A) { return !IsValid(A); });  // captura por valor
Targets.Sort([](const AActor& A, const AActor& B) { return A.GetName() < B.GetName(); });

[this]  { ... }   // captura o objeto atual (cuidado: e se ele for destruído antes de a lambda rodar?)
[&]     { ... }   // captura tudo por referência (perigoso em lambdas guardadas para depois)
```

A pergunta de segurança, sempre que uma lambda for **guardada** para executar mais tarde (num timer, num delegate, numa tarefa assíncrona): **os objetos capturados ainda existirão quando ela executar?** Capturar `this` de um ator e executar a lambda depois que ele foi destruído é um crash. Para timers e delegates, prefira as formas que vinculam a um `UObject` (`SetTimer(Handle, this, &AVGSpawner::TrySpawn, ...)`, `AddUObject`, `AddDynamic`), que a engine invalida automaticamente quando o objeto morre. O Capítulo 24 detalha os tipos de delegate.

`TFunction<Sig>` é o equivalente de `std::function` (e de uma interface funcional em Java): guarda qualquer chamável com uma assinatura.

---

## 11.11 Console variables e comandos

Duas ferramentas transformam a forma de depurar e ajustar um jogo — e não têm equivalente direto no seu dia a dia (o mais próximo seriam *feature flags* e *actuators* do Spring Boot, ajustáveis com o sistema rodando).

### Console variables (CVars)

Uma **console variable** é um valor global, ajustável pelo console durante o jogo (como os `t.MaxFPS` e `r.VSync` que você já usou), por arquivo `.ini` ou por código. Você pode criar as suas:

```cpp
// No .cpp do sistema que a usa:
static TAutoConsoleVariable<bool> CVarVGFlickerEnabled(
    TEXT("vg.Flicker.Enabled"),
    true,
    TEXT("Liga/desliga todas as falhas de luz (acessibilidade: fotossensibilidade)."),
    ECVF_Default);

// Na lógica:
if (!CVarVGFlickerEnabled.GetValueOnGameThread()) { ... }
```

O prefixo `vg.` agrupa todas as variáveis do projeto e evita colisão com as da engine. CVars são perfeitas para:

- **ligar e desligar debug visual** de um sistema (`vg.Debug.Interaction 1`);
- **ajustar valores de *feel* com o jogo rodando** antes de fixá-los em dados;
- **opções de acessibilidade e de performance**, que depois são expostas no menu de configurações (Capítulo 55).

O exemplo acima não é arbitrário. **Luzes piscando podem desencadear crises em pessoas com epilepsia fotossensível.** Jogos responsáveis oferecem opções para reduzir ou desligar efeitos de flash e flicker. Como a Vigília vai usar falhas de luz como linguagem central, essa opção é um requisito, não um detalhe — e ela nasce agora, com a primeira linha de código que liga flicker a uma configuração global.

### Comandos de console (`Exec`)

Funções marcadas com `UFUNCTION(Exec)` em certas classes — `APlayerController`, `UCheatManager`, `AGameModeBase`, o pawn possuído, entre outras — podem ser chamadas digitando o nome no console:

```cpp
// AVGPlayerController.h
UFUNCTION(Exec)
void VGDumpTimeDilation();
```

Digitar `VGDumpTimeDilation` no console executa a função. A classe dedicada a *cheats* e comandos de desenvolvimento é a **`UCheatManager`** (Capítulo 61); para começar, o PlayerController é suficiente. Comandos `Exec` são, por padrão, disponíveis em builds de desenvolvimento e removidos ou desabilitados em Shipping — verifique esse comportamento para a sua configuração antes de depender dele.

---

## 11.12 Lendo o código da engine

A instalação do launcher inclui o **código-fonte da engine** (em `Engine/Source/`). Isso muda a forma de aprender: quando a documentação não responde, a implementação responde.

Hábitos que valem desde já:

- **"Ir para a definição"** em qualquer função da engine que você usar pela primeira vez. Leia o comentário do header e, se for curta, a implementação.
- **Leia `Actor.h` e `ActorComponent.h`** com calma, uma vez. Eles são a documentação mais precisa do ciclo de vida do Capítulo 8 e do tick do Capítulo 2.
- **Procure exemplos de uso dentro da engine.** Antes de perguntar "como se usa X?", busque no código da engine onde a própria Epic usa X.
- **Desconfie de respostas sobre a engine que não citam nomes exatos** — de fóruns, tutoriais ou IA. Verifique no código.

---

## Comparação consolidada: Java vs. C++ na Unreal

| Tema | Java | C++ na Unreal |
|---|---|---|
| Organização | Um arquivo por classe; `import` simbólico | `.h` + `.cpp`; `#include` textual; *forward declarations* |
| Objetos | Sempre referências | Valores, referências ou ponteiros; `UObject` sempre por ponteiro |
| Memória de objetos de jogo | GC da JVM, descoberta automática de referências | GC da Unreal, **só enxerga `UPROPERTY`** |
| Memória de outros objetos | GC | RAII, `TUniquePtr`, `TSharedPtr` |
| Imutabilidade | `final`, records | `const` (métodos, parâmetros, retornos) |
| Reflexão | Nativa, em runtime | Macros + UHT, gerada em compilação |
| Coleções | `ArrayList`, `HashMap` | `TArray`, `TMap`, `TSet` |
| Strings | `String` | `FString` (texto), `FName` (identificador), `FText` (jogador) |
| Erros | Exceções | Retorno/verificação, `ensure`, `check`; sem exceções |
| Casting | `instanceof` + cast | `Cast<T>` (via reflexão) |
| Anotações | Processadas em compilação ou runtime | `UPROPERTY`/`UFUNCTION` — essenciais, não opcionais |
| Config em runtime | Actuators, feature flags | CVars, comandos `Exec` |

---

## Implementação

### 1. Categoria de log do projeto

Crie `Core/VGLog.h` e `Core/VGLog.cpp` (seção 11.9) e substitua os `LogTemp` de `AVGSpawner` e `UVGFlickerComponent`.

### 2. Flicker com chave global de acessibilidade

```cpp
// Source/Vigilia/World/VGFlickerComponent.cpp (trechos novos)
#include "Core/VGLog.h"
#include "HAL/IConsoleManager.h"

static TAutoConsoleVariable<bool> CVarVGFlickerEnabled(
    TEXT("vg.Flicker.Enabled"),
    true,
    TEXT("Liga/desliga todas as falhas de luz (acessibilidade: fotossensibilidade)."),
    ECVF_Default);

void UVGFlickerComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                        FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    if (!CVarVGFlickerEnabled.GetValueOnGameThread())
    {
        if (CurrentScale != 1.0f)
        {
            CurrentScale = 1.0f;
            ApplyScale(CurrentScale); // luz estável enquanto o flicker estiver desligado
        }
        return;
    }

    // ... resto igual ao Capítulo 9
}
```

Note uma escolha consciente: com o flicker desligado, o componente **continua tickando** (barato: uma leitura de CVar e um retorno) para poder religar sozinho quando a opção mudar. A alternativa — desligar o tick e religar por um evento de mudança da CVar — é mais eficiente e mais complexa. Com dezenas de lâmpadas, o custo é irrelevante; anote-a como `// Simplificação:` no código e revise no Capítulo 60 se o profiler apontar.

### 3. Inspecionando a dilatação do tempo pelo console

No Capítulo 6, o exercício pedia uma forma de ver os pedidos de dilatação ativos. Agora, com `Exec`, isso vira um comando. Primeiro, o subsistema ganha uma função de descrição:

```cpp
// VGTimeDilationSubsystem.h (adição)
public:
    /** Linhas legíveis com os pedidos ativos, para depuração. */
    void DescribeRequests(TArray<FString>& OutLines) const;
```

```cpp
// VGTimeDilationSubsystem.cpp (adição)
void UVGTimeDilationSubsystem::DescribeRequests(TArray<FString>& OutLines) const
{
    OutLines.Add(FString::Printf(TEXT("Efetiva: %.3f (%d pedidos)"), EffectiveDilation, ActiveRequests.Num()));
    for (const TPair<int32, FVGTimeDilationRequest>& Pair : ActiveRequests)
    {
        OutLines.Add(FString::Printf(TEXT("  #%d  %-16s  escala=%.3f  prioridade=%d"),
            Pair.Key, *Pair.Value.Reason.ToString(), Pair.Value.Scale, Pair.Value.Priority));
    }
}
```

E o PlayerController ganha o comando:

```cpp
// VGPlayerController.h (adição)
public:
    UFUNCTION(Exec)
    void VGDumpTimeDilation();
```

```cpp
// VGPlayerController.cpp
#include "Player/VGPlayerController.h"

#include "Core/VGLog.h"
#include "Core/VGTimeDilationSubsystem.h"

void AVGPlayerController::VGDumpTimeDilation()
{
    const UVGTimeDilationSubsystem* Time = GetWorld()->GetSubsystem<UVGTimeDilationSubsystem>();
    if (!Time)
    {
        UE_LOG(LogVigilia, Warning, TEXT("VGDumpTimeDilation: subsistema indisponível neste mundo."));
        return;
    }

    TArray<FString> Lines;
    Time->DescribeRequests(Lines);
    for (const FString& Line : Lines)
    {
        UE_LOG(LogVigilia, Display, TEXT("%s"), *Line);
    }
}
```

A separação é deliberada: o **subsistema descreve** o próprio estado (ele é o dono, e sabe formatá-lo); o **PlayerController apenas expõe** a descrição ao console. Amanhã, a mesma `DescribeRequests` alimenta um painel de debug na tela (Capítulo 61) sem mudar uma linha do subsistema.

---

## Decisões arquiteturais

1. **Forward declarations nos headers; includes nos `.cpp`.**
2. **Todo ponteiro de membro para `UObject` é `UPROPERTY()`**, com `TObjectPtr`. Ponteiros crus só em locais e parâmetros.
3. **`TWeakObjectPtr` para observar sem possuir; `TSoftObjectPtr` para assets sob demanda; `TSubclassOf` para classes escolhidas no editor.**
4. **Contêineres e strings da Unreal**, não da biblioteca padrão. Texto do jogador é sempre `FText`.
5. **Sem exceções:** verificação + log para o esperado, `ensure` para bugs recuperáveis, `check` só para o irrecuperável e sem efeitos colaterais.
6. **`LogVigilia`** como categoria do projeto; categorias estáticas só para diagnóstico isolado.
7. **CVars com prefixo `vg.`** para debug, ajuste de *feel*, performance e acessibilidade.
8. **Comandos de desenvolvimento via `Exec`**, migrando para `UCheatManager` no Capítulo 61.
9. **Escolha consciente entre `EditAnywhere`, `EditDefaultsOnly` e `EditInstanceOnly`.**

---

## Armadilhas

- **Ponteiro para `UObject` como membro sem `UPROPERTY`.** O bug mais grave e mais comum deste capítulo.
- **`new`/`delete` ou `TSharedPtr` com `UObject`s.**
- **Lógica com efeito colateral dentro de `check`.**
- **`if (Ptr)` em vez de `IsValid(Ptr)`** para objetos que podem ter sido destruídos.
- **Remover elementos de um `TArray` durante um *range-for*.**
- **`FString` para texto exibido ao jogador.**
- **Esquecer o `*` antes de um `FString` num `UE_LOG`.**
- **Lambdas guardadas capturando `this` ou referências** que podem morrer antes da execução.
- **Includes em excesso nos headers**, e confiar em includes "emprestados" pelo unity build.
- **Copiar structs grandes por valor** em parâmetros por descuido.
- **Acreditar em nomes de API sem verificar** no código da engine.

---

## Exercício

**Parte 1 — o bug do ponteiro invisível (1 h).** Crie um ator de teste com dois membros apontando para um `UObject` criado com `NewObject` (sem nenhuma outra referência): um com `UPROPERTY()` e outro sem. Force uma coleta de lixo pelo console (`obj gc`) e verifique, num tick ou por um comando `Exec`, o estado dos dois ponteiros. Registre o resultado e explique. *(Execute este experimento em `/Game/Developers/` e apague depois.)*

**Parte 2 — refatoração (1 h).** Crie `LogVigilia`, substitua os `LogTemp` do projeto, adicione a CVar `vg.Flicker.Enabled` e o comando `VGDumpTimeDilation`. Teste os dois durante o PIE.

**Parte 3 — leitura de engine (1 h).** Abra `Actor.h` e encontre: a declaração de `BeginPlay`, `EndPlay`, `Tick`, `SetLifeSpan`, `InitialLifeSpan`, `CustomTimeDilation` e `OnDestroyed`. Para cada um, anote a linha de comentário da Epic e compare com o que os Capítulos 2, 3 e 8 disseram. Encontrou alguma divergência?

**Parte 4 — strings (30 min).** Revise o código do projeto: algum texto que um dia será mostrado ao jogador está como `FString`? Algum identificador está como `FString` quando deveria ser `FName`? Corrija.

---

## Desafio — uma CVar de debug visual

Crie a CVar `vg.Debug.Flicker` (inteiro: 0 desligado, 1 ligado). Quando ligada, cada `UVGFlickerComponent` deve desenhar, acima do seu ator, um texto com o padrão atual e a escala corrente (`DrawDebugString`), e uma esfera cujo tamanho acompanha a escala (`DrawDebugSphere`). Garanta que:

1. Com a CVar desligada, nenhum custo de debug é pago (nem formatação de string).
2. O código de debug não existe em builds Shipping (pesquise as macros de compilação condicional da Unreal, como `UE_BUILD_SHIPPING` e `ENABLE_DRAW_DEBUG`).
3. A CVar pode ser ligada pelo console durante o PIE e o efeito aparece imediatamente.

Reflita: que outros sistemas da Vigília vão precisar de uma CVar `vg.Debug.*`? Comece uma lista no `DEVLOG.md` — ela vira o painel de debug do Capítulo 61.

---

## Uso de IA

1. **Para traduzir intuições de Java:**
   > "Sou programador Java experiente começando C++ na Unreal Engine 5. Para cada item, explique a diferença e o erro típico de quem vem de Java: passagem de objetos por valor vs. referência, const, ponteiros para UObject e o garbage collector da Unreal, ausência de exceções, FString/FName/FText, remoção de elementos durante iteração e captura em lambdas. Dê um exemplo de código errado e corrigido para cada um."

2. **Para revisar segurança de memória:**
   > "Revise este código C++ da Unreal com foco exclusivo em segurança de memória e ciclo de vida: ponteiros para UObject sem UPROPERTY, uso de objetos possivelmente destruídos sem IsValid, lambdas guardadas capturando this, delegates não removidos, uso de new/delete ou TSharedPtr com UObjects. [código]"

3. **Para entender código gerado:**
   > "Explique o que o Unreal Header Tool gera para uma classe com UCLASS, uma UPROPERTY e uma UFUNCTION(BlueprintCallable). Onde ficam os arquivos gerados, o que GENERATED_BODY insere na classe e como o editor e o garbage collector usam essas informações? Diga explicitamente o que pode variar entre versões."

**Cuidado específico:** C++ da Unreal é um domínio onde IAs frequentemente misturam convenções da biblioteca padrão com as da engine (sugerindo `std::vector` ou `std::shared_ptr` com `UObject`s), inventam especificadores de `UPROPERTY` ou usam APIs de versões antigas (UE4). Compile, e confira cada API desconhecida no código da engine.

---

## Checklist

- [ ] Sei por que headers custam tempo de build e uso forward declarations.
- [ ] Sei escolher entre valor, `const&`, ponteiro e referência de saída.
- [ ] Sei separar os dois mundos de memória e nunca misturo ponteiros inteligentes com `UObject`s.
- [ ] Conheço os especificadores principais de `UPROPERTY` e `UFUNCTION` e escolho `Edit*` com intenção.
- [ ] Sei por que todo membro ponteiro para `UObject` precisa de `UPROPERTY` e reproduzi o bug.
- [ ] Sei quando usar `TObjectPtr`, `TWeakObjectPtr`, `TSoftObjectPtr` e `TSubclassOf`.
- [ ] Sei usar `TArray`, `TMap`, `TSet` e escolher entre `FString`, `FName` e `FText`.
- [ ] Sei tratar erros com verificação, `ensure` e `check`.
- [ ] Criei `LogVigilia`, a CVar `vg.Flicker.Enabled` e o comando `VGDumpTimeDilation`.
- [ ] Sei navegar no código-fonte da engine para responder dúvidas.

---

## Para ir além

- **cppreference.com** — referência da linguagem e da biblioteca padrão; use para entender os conceitos de C++ por trás dos equivalentes da Unreal.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Programming with C++**, **Unreal Object Handling**, **Garbage Collection**, **Properties** e **UFunctions** (com a lista completa de especificadores), **Containers**, **String Handling**, **Console Variables**, **Logging**.
- **Código-fonte da engine** — `Engine/Source/Runtime/Engine/Classes/GameFramework/Actor.h` e `Engine/Source/Runtime/Engine/Classes/Components/ActorComponent.h`.
- **Scott Meyers, *Effective Modern C++*** — se quiser aprofundar C++11/14 (move semantics, ponteiros inteligentes, lambdas) fora do contexto da engine.

---

➡️ **Próximo:** [Capítulo 12 — Blueprint](cap-12-blueprint.md)
