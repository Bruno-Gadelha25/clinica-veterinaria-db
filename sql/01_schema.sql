-- =====================================================================
--  CLÍNICA VETERINÁRIA — 01_schema.sql
--  Etapa 1: criação do banco e das tabelas (modelo FÍSICO)
--  SGBD: MySQL 8
-- =====================================================================
--  Ordem de criação importa: uma tabela só pode ter FOREIGN KEY
--  apontando para uma tabela que JÁ EXISTE. Por isso criamos primeiro
--  as tabelas "independentes" (sem FK) e depois as que dependem delas.
-- =====================================================================

DROP DATABASE IF EXISTS clinica_veterinaria;
CREATE DATABASE clinica_veterinaria
    CHARACTER SET utf8mb4          -- aceita acento, ç e até emoji
    COLLATE utf8mb4_0900_ai_ci;    -- comparação sem diferenciar acento/maiúscula

USE clinica_veterinaria;

-- ---------------------------------------------------------------------
-- TUTOR: o dono do pet (quem paga a conta)
-- ---------------------------------------------------------------------
CREATE TABLE tutor (
    id_tutor       INT UNSIGNED AUTO_INCREMENT,
    nome           VARCHAR(100) NOT NULL,
    cpf            CHAR(11)     NOT NULL,          -- CHAR: sempre 11 dígitos, sem pontuação
    telefone       VARCHAR(15)  NOT NULL,
    email          VARCHAR(100),                   -- opcional: aceita NULL
    data_cadastro  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_tutor     PRIMARY KEY (id_tutor),
    CONSTRAINT uq_tutor_cpf UNIQUE (cpf)           -- dois tutores não podem ter o mesmo CPF
);

-- ---------------------------------------------------------------------
-- ESPÉCIE e RAÇA: separadas para evitar repetição (normalização).
-- Se "Cachorro" fosse texto livre em pet, alguém digitaria "cachoro",
-- "Cão", "cachorro"... e os relatórios quebrariam.
-- ---------------------------------------------------------------------
CREATE TABLE especie (
    id_especie  INT UNSIGNED AUTO_INCREMENT,
    nome        VARCHAR(50) NOT NULL,

    CONSTRAINT pk_especie      PRIMARY KEY (id_especie),
    CONSTRAINT uq_especie_nome UNIQUE (nome)
);

-- Uma espécie tem várias raças (1:N) -> a FK fica no lado "N" (raca)
CREATE TABLE raca (
    id_raca     INT UNSIGNED AUTO_INCREMENT,
    id_especie  INT UNSIGNED NOT NULL,
    nome        VARCHAR(50)  NOT NULL,

    CONSTRAINT pk_raca         PRIMARY KEY (id_raca),
    CONSTRAINT fk_raca_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie),
    CONSTRAINT uq_raca         UNIQUE (id_especie, nome)   -- "SRD" pode existir p/ cão E p/ gato
);

-- ---------------------------------------------------------------------
-- PET: um tutor tem vários pets (1:N); cada pet tem uma raça (N:1)
-- ---------------------------------------------------------------------
CREATE TABLE pet (
    id_pet           INT UNSIGNED AUTO_INCREMENT,
    id_tutor         INT UNSIGNED  NOT NULL,
    id_raca          INT UNSIGNED  NOT NULL,
    nome             VARCHAR(50)   NOT NULL,
    sexo             ENUM('M','F') NOT NULL,
    data_nascimento  DATE,                          -- NULL = idade desconhecida (pet resgatado)
    peso_kg          DECIMAL(5,2),                  -- até 999,99 kg — DECIMAL é exato, FLOAT não
    castrado         BOOLEAN       NOT NULL DEFAULT FALSE,
    ativo            BOOLEAN       NOT NULL DEFAULT TRUE,  -- "apagar" pet = desativar (mantém histórico)

    CONSTRAINT pk_pet       PRIMARY KEY (id_pet),
    CONSTRAINT fk_pet_tutor FOREIGN KEY (id_tutor) REFERENCES tutor (id_tutor),
    CONSTRAINT fk_pet_raca  FOREIGN KEY (id_raca)  REFERENCES raca  (id_raca),
    CONSTRAINT ck_pet_peso  CHECK (peso_kg > 0)
);

-- ---------------------------------------------------------------------
-- VETERINÁRIO e ESPECIALIDADE: relação N:N
-- (um vet tem várias especialidades; uma especialidade tem vários vets)
-- N:N NUNCA vira FK direta: precisa de uma TABELA ASSOCIATIVA no meio.
-- ---------------------------------------------------------------------
CREATE TABLE veterinario (
    id_veterinario  INT UNSIGNED AUTO_INCREMENT,
    nome            VARCHAR(100) NOT NULL,
    crmv            VARCHAR(20)  NOT NULL,          -- registro profissional (ex.: CRMV-SP 12345)
    telefone        VARCHAR(15),
    email           VARCHAR(100),

    CONSTRAINT pk_veterinario PRIMARY KEY (id_veterinario),
    CONSTRAINT uq_vet_crmv    UNIQUE (crmv)
);

CREATE TABLE especialidade (
    id_especialidade  INT UNSIGNED AUTO_INCREMENT,
    nome              VARCHAR(60) NOT NULL,

    CONSTRAINT pk_especialidade PRIMARY KEY (id_especialidade),
    CONSTRAINT uq_espec_nome    UNIQUE (nome)
);

-- Tabela associativa: a PK é COMPOSTA pelas duas FKs,
-- o que impede cadastrar a mesma especialidade duas vezes pro mesmo vet.
CREATE TABLE veterinario_especialidade (
    id_veterinario    INT UNSIGNED NOT NULL,
    id_especialidade  INT UNSIGNED NOT NULL,

    CONSTRAINT pk_vet_espec PRIMARY KEY (id_veterinario, id_especialidade),
    CONSTRAINT fk_ve_vet    FOREIGN KEY (id_veterinario)   REFERENCES veterinario   (id_veterinario) ON DELETE CASCADE,
    CONSTRAINT fk_ve_espec  FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade)
);

-- ---------------------------------------------------------------------
-- SERVIÇO: catálogo do que a clínica cobra (consulta, exame, banho...)
-- ---------------------------------------------------------------------
CREATE TABLE servico (
    id_servico  INT UNSIGNED AUTO_INCREMENT,
    nome        VARCHAR(80)   NOT NULL,
    preco_base  DECIMAL(10,2) NOT NULL,             -- dinheiro = SEMPRE DECIMAL

    CONSTRAINT pk_servico      PRIMARY KEY (id_servico),
    CONSTRAINT uq_servico_nome UNIQUE (nome),
    CONSTRAINT ck_servico_preco CHECK (preco_base >= 0)
);

-- ---------------------------------------------------------------------
-- CONSULTA: o "coração" do sistema. Liga pet + veterinário + horário.
-- ---------------------------------------------------------------------
CREATE TABLE consulta (
    id_consulta     INT UNSIGNED AUTO_INCREMENT,
    id_pet          INT UNSIGNED NOT NULL,
    id_veterinario  INT UNSIGNED NOT NULL,
    data_hora       DATETIME     NOT NULL,
    status          ENUM('agendada','realizada','cancelada') NOT NULL DEFAULT 'agendada',
    motivo          VARCHAR(255) NOT NULL,
    diagnostico     TEXT,                           -- só preenchido depois do atendimento

    CONSTRAINT pk_consulta      PRIMARY KEY (id_consulta),
    CONSTRAINT fk_consulta_pet  FOREIGN KEY (id_pet)         REFERENCES pet         (id_pet),
    CONSTRAINT fk_consulta_vet  FOREIGN KEY (id_veterinario) REFERENCES veterinario (id_veterinario),
    CONSTRAINT uq_agenda_vet    UNIQUE (id_veterinario, data_hora)  -- vet não atende 2 no mesmo horário
);

-- ---------------------------------------------------------------------
-- CONSULTA_SERVICO: N:N entre consulta e serviço, COM atributos extras.
-- Por que guardar preco_cobrado se já existe servico.preco_base?
-- Porque o preço muda com o tempo! Se a vacina subir de 80 pra 100,
-- a consulta do ano passado tem que continuar mostrando 80.
-- ---------------------------------------------------------------------
CREATE TABLE consulta_servico (
    id_consulta    INT UNSIGNED  NOT NULL,
    id_servico     INT UNSIGNED  NOT NULL,
    quantidade     SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    preco_cobrado  DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_consulta_servico PRIMARY KEY (id_consulta, id_servico),
    CONSTRAINT fk_cs_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta) ON DELETE CASCADE,
    CONSTRAINT fk_cs_servico  FOREIGN KEY (id_servico)  REFERENCES servico  (id_servico),
    CONSTRAINT ck_cs_qtd      CHECK (quantidade > 0)
);

-- ---------------------------------------------------------------------
-- VACINA e APLICACAO_VACINA: carteira de vacinação do pet
-- ---------------------------------------------------------------------
CREATE TABLE vacina (
    id_vacina               INT UNSIGNED AUTO_INCREMENT,
    nome                    VARCHAR(80)       NOT NULL,
    intervalo_reforco_dias  SMALLINT UNSIGNED NOT NULL,   -- ex.: 365 = reforço anual

    CONSTRAINT pk_vacina      PRIMARY KEY (id_vacina),
    CONSTRAINT uq_vacina_nome UNIQUE (nome)
);

CREATE TABLE aplicacao_vacina (
    id_aplicacao       INT UNSIGNED AUTO_INCREMENT,
    id_pet             INT UNSIGNED NOT NULL,
    id_vacina          INT UNSIGNED NOT NULL,
    id_veterinario     INT UNSIGNED NOT NULL,
    data_aplicacao     DATE         NOT NULL,
    data_proxima_dose  DATE,                       -- calculada automaticamente por TRIGGER (etapa 4)
    lote               VARCHAR(30)  NOT NULL,

    CONSTRAINT pk_aplicacao     PRIMARY KEY (id_aplicacao),
    CONSTRAINT fk_apl_pet       FOREIGN KEY (id_pet)         REFERENCES pet         (id_pet),
    CONSTRAINT fk_apl_vacina    FOREIGN KEY (id_vacina)      REFERENCES vacina      (id_vacina),
    CONSTRAINT fk_apl_vet       FOREIGN KEY (id_veterinario) REFERENCES veterinario (id_veterinario)
);

-- ---------------------------------------------------------------------
-- ✍️  EXERCÍCIO PRA VOCÊ: tabela PAGAMENTO
-- ---------------------------------------------------------------------
-- Regras do negócio:
--   1. Todo pagamento é de UMA consulta, e uma consulta é paga UMA vez só (1:1)
--   2. Guardar: valor, forma de pagamento e data/hora do pagamento
--   3. Formas aceitas: dinheiro, pix, debito, credito
--   4. Valor não pode ser negativo
--   5. Se não informar a data, usa o momento atual
--
-- Dicas:
--   - Olhe como fizemos "status" em consulta (ENUM) e "data_cadastro" em tutor (DEFAULT)
--   - 1:1 = uma FK + UNIQUE nessa mesma coluna. Por quê? Pense um pouco antes de ver o gabarito 😉
--   - Dê nome às constraints seguindo o padrão: pk_, fk_, uq_, ck_
--
-- Escreva aqui embaixo:

