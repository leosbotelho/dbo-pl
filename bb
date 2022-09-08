create table TgBlock (
  BlockHash  binary(32) not null,
  BlockDtm   datetime(0) not null,
  TgName     char(22) not null,
  Dtm        datetime(3) not null,

  Primary Key (TgName, Dtm, BlockDtm),

  Constraint TgBlock_AK1 Unique (BlockDtm, TgName),
  Constraint TgBlock_AK2 Unique (BlockHash, TgName),

  Foreign Key (TgName) references Ref_TgName (Name)
);

create table Prov (
  StatHash    bigint unsigned not null,
  Hash        bigint unsigned not null,
  Des         enum('Tg', 'Cg', 'Github') not null,
  Dtm         datetime(3) not null,
  UpdatedDtm  datetime(3) not null,
  IsObsolete  boolean not null default false,

  -- CI
  Primary Key (IsObsolete, Des, StatHash, Dtm, Hash),

  Constraint Prov_PK Unique (Hash),

  Unique (UpdatedDtm, Hash)
);

create table ProvBlock (
  ProvHash  bigint unsigned not null,
  BlockDtm  datetime(0) not null,

  -- CI
  Primary Key (BlockDtm, ProvHash),

  Constraint ProvBlock_PK Unique (ProvHash),

  Foreign Key (ProvHash) references Prov (Hash),
  Foreign Key (BlockDtm) references BB.Env_CurBlock (BlockDtm)
);

create table ProvDtm (
  ProvHash  bigint unsigned not null,
  Dtm       datetime(3) not null,

  -- CI
  Primary Key (Dtm, ProvHash),

  Constraint ProvDtm_PK Unique (ProvHash),

  Foreign Key (ProvHash) references Prov (Hash)
);

create table TgProv (
  ProvHash  bigint unsigned not null,
  TgName    char(22) not null,
  Name      char(18) not null,

  -- CI
  Primary Key (TgName, Name, ProvHash),

  Constraint TgProv_PK Unique (ProvHash),

  Foreign Key (ProvHash) references Prov (Hash),
  Foreign Key (TgName) references BB.Ref_TgName (Name)
);

create table CgTlProv (
  ProvHash  bigint unsigned not null,
  Id        enum('uniswap') not null,
  -- opt ts(0)
  Dtm       datetime(3) not null,

  -- CI
  Primary Key (Id, ProvHash),

  Constraint CgTlProv_PK Unique (ProvHash),

  Foreign Key (ProvHash) references Prov (Hash),

  Unique (Dtm, ProvHash)
);

create table GithubProv (
  ProvHash        bigint unsigned not null,
  GithubPathName  char(7) not null,
  -- opt ts(0)
  CommitDtm       datetime(3) not null,

  -- CI
  Primary Key (GithubPathName, ProvHash),

  Constraint GithubProv_PK Unique (ProvHash),

  Foreign Key (ProvHash) references Prov (Hash),
  Foreign Key (GithubPathName) references BB.Ref_GithubPath ($Name),

  Unique (CommitDtm, ProvHash)
);

create table Addr (
  Hash   bigint unsigned not null,
  Des    enum('Token', 'Pair') not null,
  Addr   binary(20) not null,
  Dtm    datetime(3) not null,

  -- CI
  Primary Key (Des, Hash, Addr),

  Constraint Addr_PK Unique (Addr),
  Constraint Addr_AK Unique (Hash),

  Unique (Dtm, Hash)
);

create table Token (
  Hash        bigint unsigned not null,
  $ChainDes   enum('Filled', 'Reported') not null,
  $ChainId    int not null,
  Decimals    tinyint unsigned not null,
  Dtm         datetime(3) not null,
  UpdatedDtm  datetime(3) not null,

  -- CI
  Primary Key ($ChainId, $ChainDes, Dtm, Hash),

  Constraint Token_PK Unique (Hash),

  Foreign Key ($ChainId) references Ref_Chain (Id),

  Unique (UpdatedDtm, Hash)
);

create table TokenProv (
  TokenHash  bigint unsigned not null,
  ProvHash   bigint unsigned not null,
  Newest     boolean not null default true,

  Primary Key (TokenHash, ProvHash),

  Constraint TokenProv_AK Unique (ProvHash, TokenHash),

  Foreign Key (TokenHash) references Token (Hash),
  Foreign Key (ProvHash) references Prov (Hash),

  Unique (Newest, TokenHash, ProvHash)
);

create table TokenAddr (
  TokenHash  bigint unsigned not null,
  AddrHash   bigint unsigned not null,

  Primary Key (TokenHash),
  Constraint TokenAddr_AK Unique (AddrHash),

  Foreign Key (TokenHash) references Token (Hash),
  Foreign Key (AddrHash) references Addr (Hash)
);

create table Var_Token (
  Hash  bigint unsigned not null,
  Sym   varchar(30) charset utf8mb4 not null,
  Name  varchar(50) charset utf8mb4 not null,

  Primary Key (Hash),
  Foreign Key (Hash) references Token (Hash)
)
row_format=dynamic;

create table Var_Token_O (
  Hash  bigint unsigned not null,
  Sym   text charset utf8mb4 not null,
  Name  text charset utf8mb4 not null,

  Primary Key (Hash),
  Foreign Key (Hash) references Token (Hash)
)
row_format=dynamic;

create table Pair (
  Hash        bigint unsigned not null,
  $ChainId    int not null,
  FeeTier     smallint unsigned not null,
  Dtm         datetime(3) not null,
  UpdatedDtm  datetime(3) not null,

  -- CI
  Primary Key ($ChainId, FeeTier, Dtm, Hash),

  Constraint Pair_PK Unique (Hash),

  Unique (UpdatedDtm, Hash)
);

create table PairProv (
  PairHash  bigint unsigned not null,
  ProvHash  bigint unsigned not null,

  -- CI
  Primary Key (ProvHash, PairHash),

  Constraint TokenProv_PK Unique (PairHash),

  Foreign Key (PairHash) references Pair (Hash),
  Foreign Key (ProvHash) references Prov (Hash)
);

create table PairAddr (
  PairHash  bigint unsigned not null,
  AddrHash  bigint unsigned not null,

  Primary Key (PairHash),
  Constraint PairAddr_AK Unique (AddrHash),

  Foreign Key (PairHash) references Pair (Hash),
  Foreign Key (AddrHash) references Addr (Hash)
);

create table PairTokenAddr (
  PairHash       bigint unsigned not null,
  Des            enum('I', 'O') not null,
  TokenAddrHash  bigint unsigned not null,

  Primary Key (PairHash, Des, TokenAddrHash),

  Foreign Key (PairHash) references Pair (Hash),
  Foreign Key (TokenAddrHash) references TokenAddr (AddrHash)
);

create table PairB (
  PairHash  bigint unsigned not null,
  Des       enum('PairDailyByTxCount', 'PairByReserveUsd') not null,
  Dtm       datetime(3) not null,

  -- CI
  Primary Key (Des, Dtm, Hash),

  Constraint PairB_PK Unique (Hash),

  Foreign Key (Hash) references Pair (Hash)
);

create table PairDailyByTxCount (
  Hash        bigint unsigned not null,
  TxCount     int unsigned not null,
  VolumeUsd   bigint unsigned not null,

  Primary Key (Hash),
  Foreign Key (Hash) references PairB (Hash)
);

create table PairByReserveUsd (
  Hash        bigint unsigned not null,
  ReserveUsd  bigint unsigned not null,

  Primary Key (Hash),
  Foreign Key (Hash) references PairB (Hash)
);
