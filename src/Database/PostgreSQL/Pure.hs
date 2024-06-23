{-# LANGUAGE CPP                        #-}
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DefaultSignatures          #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE DuplicateRecordFields      #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE InstanceSigs               #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NamedFieldPuns             #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}

{-# OPTIONS_GHC -Wno-redundant-constraints #-} -- These warnings are raised, although constraints are necessary.
{-# OPTIONS_GHC -Wno-unused-top-binds #-} -- These warnings are raised, although "builder", "parser" fields are necessary for IsLabel instances.

-- |
-- This is a client library for PostgreSQL Database which has following features.
--
--     - faster and less CPU load
--
--         - especially on multi-core environments
--
--     - pure Haskell implementations
--
--         - no libpq dependency
--         - easy to build even on Windows
--
--     - implements extended query protocol
--
--         - about extended query protocol, see <https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY>
--
-- = Typical Example
--
-- Prepare a following table.
--
-- @
-- CREATE TABLE person (
--   id serial PRIMARY KEY,
--   name varchar(255) NOT NULL
-- );
-- INSERT INTO person (name) VALUES (\'Ada\');
-- @
--
-- You can run like following to get the record whose ID is 1.
--
-- >>> :set -XOverloadedStrings
-- >>> :set -XFlexibleContexts
-- >>> :set -XDataKinds
-- >>> :set -XTypeFamilies
-- >>> :set -XTypeApplications
-- >>>
-- >>> import Database.PostgreSQL.Pure
-- >>> import Data.Default.Class (def)
-- >>> import Data.Int (Int32)
-- >>> import Data.ByteString (ByteString)
-- >>> import Data.Tuple.Only (Only (Only))
-- >>> import Data.Tuple.Homotuple.Only ()
-- >>> import Data.Maybe (fromMaybe)
-- >>> import System.Environment (lookupEnv)
-- >>>
-- >>> getEnvDef name value = fromMaybe value <$> lookupEnv name
-- >>>
-- >>> host' <- getEnvDef "PURE_HOST" "127.0.0.1"
-- >>> port' <- getEnvDef "PURE_PORT" "5432"
-- >>> user' <- getEnvDef "PURE_USER" "postgres"
-- >>> password' <- getEnvDef "PURE_PASSWORD" ""
-- >>> database' <- getEnvDef "PURE_DATABASE" "postgres"
-- >>>
-- >>> conn <- connect def { address = AddressNotResolved host' port', user = user', password = password', database = database' }
-- >>> preparedStatementProcedure = parse "" "SELECT id, name FROM person WHERE id = $1" Nothing
-- >>> portalProcedure <- bind @_ @2 @_ @_ "" BinaryFormat BinaryFormat (parameters conn) (const $ fail "") (Only (1 :: Int32)) preparedStatementProcedure
-- >>> executedProcedure = execute @_ @_ @(Int32, ByteString) 0 (const $ fail "") portalProcedure
-- >>> ((_, _, e, _), _) <- sync conn executedProcedure
-- >>> records e
-- [(1,"Ada")]
module Database.PostgreSQL.Pure
  ( -- * Connection
    Config (..)
  , Connection
  , pid
  , parameters
  , config
  , Address (..)
  , BackendParameters
  , Pid
  , withConnection
  , connect
  , disconnect
    -- * Extended Query
  , parse
  , bind
  , execute
  , flush
  , sync
  , close
  , PreparedStatement
  , PreparedStatementProcedure
  , PreparedStatementName (..)
  , Portal
  , PortalProcedure
  , PortalName (..)
  , Executed
  , ExecutedProcedure
  , ExecuteResult (..)
  , CloseProcedure
  , CommandTag (..)
  , Query (..)
  , FormatCode (..)
  , ColumnInfo
  , Message
  , MessageResult
  , Bind
  , Execute
  , Close
  , StringEncoder
  , StringDecoder
  , HasName
  , Name
  , HasParameterOids
  , name
  , parameterOids
  , resultInfos
  , result
  , records
    -- * Transaction
  , begin
  , commit
  , rollback
  , TransactionState (..)
    -- * Record
  , FromField (..)
  , FromRecord (..)
  , ToField (..)
  , ToRecord (..)
  , Raw (..)
  , SqlIdentifier (..)
  , TimeOfDayWithTimeZone (..)
  , Length
    -- * Exception
  , Exception.Exception (..)
  , Exception.ErrorResponse (..)
  , Exception.ResponseParsingFailed (..)
    -- * OID
  , Oid
  ) where

import           Database.PostgreSQL.Pure.Internal.Connection (connect, disconnect, withConnection)
import           Database.PostgreSQL.Pure.Internal.Data       (Address (AddressNotResolved, AddressResolved),
                                                               BackendParameters, CloseProcedure, ColumnInfo,
                                                               CommandTag (AlterTableTag, BeginTag, CommitTag, CopyTag, CreateSchemaTag, CreateTableTag, DeleteTag, DropSchemaTag, DropTableTag, FetchTag, InsertTag, MoveTag, RollbackTag, SelectTag, StartTransactionTag, UpdateTag),
                                                               Config (Config, address, database, password, receptionBufferSize, sendingBufferSize, user),
                                                               Connection (config, parameters, pid), ErrorFields,
                                                               ExecuteResult (ExecuteComplete, ExecuteEmptyQuery, ExecuteSuspended),
                                                               FormatCode (BinaryFormat, TextFormat),
                                                               FromField (fromField), FromRecord (fromRecord),
                                                               MessageResult, Oid, Pid, PortalName (PortalName),
                                                               PreparedStatementName (PreparedStatementName),
                                                               Query (Query), Raw (Null, Value),
                                                               SqlIdentifier (SqlIdentifier), StringDecoder,
                                                               StringEncoder,
                                                               TimeOfDayWithTimeZone (TimeOfDayWithTimeZone, timeOfDay, timeZone),
                                                               ToField (toField), ToRecord (toRecord), TransactionState)
import qualified Database.PostgreSQL.Pure.Internal.Data       as Data
import qualified Database.PostgreSQL.Pure.Internal.Exception  as Exception
import           Database.PostgreSQL.Pure.Internal.Length     (Length)
import           Database.PostgreSQL.Pure.Internal.Query      (Close, Message, close, flush, sync)
import qualified Database.PostgreSQL.Pure.Internal.Query      as Query

import           Data.Bifunctor                               (bimap)
import           Data.Kind                                    (Type)
import           Data.Proxy                                   (Proxy (Proxy))
import           Data.Tuple.Homotuple                         (Homotuple)
import qualified Data.Tuple.List                              as Tuple
import           GHC.Exts                                     (IsList (Item, fromList, toList))
import           GHC.Records                                  (HasField (getField))
import           GHC.TypeLits                                 (KnownNat, Nat, natVal)

#if !MIN_VERSION_base(4,13,0)
import           Control.Monad.Fail                           (MonadFail)
#endif

-- | This represents a prepared statement which is already processed by a server.
--
-- @parameterLength@ is the number of columns of the parameter and @resultLength@ is the number of columns of the results.
-- This is the same with 'PreparedStatementProcedure', 'Portal', 'PortalProcedure', 'Executed' and 'ExecutedProcedure'.
newtype PreparedStatement (parameterLength :: Nat) (resultLength :: Nat) =
  PreparedStatement Data.PreparedStatement
  deriving newtype (Show, Eq, Close)

instance HasField "name" (PreparedStatement n m) PreparedStatementName where
  getField (PreparedStatement Data.PreparedStatement { name }) = name

instance (oids ~ Homotuple n Oid, Item oids ~ Oid, IsList oids) => HasField "parameterOids" (PreparedStatement n m) oids where
  getField (PreparedStatement Data.PreparedStatement { parameterOids }) = fromList parameterOids

-- | To get a list of column infos of the result record.
resultInfos :: (IsList (Homotuple m ColumnInfo), ColumnInfo ~ Item (Homotuple m ColumnInfo)) => PreparedStatement n m -> Homotuple m ColumnInfo
resultInfos (PreparedStatement Data.PreparedStatement { resultInfos }) = fromList resultInfos

-- | This represents a prepared statement which is not yet processed by a server.
newtype PreparedStatementProcedure (parameterLength :: Nat) (resultLength :: Nat) =
  PreparedStatementProcedure Data.PreparedStatementProcedure
  deriving newtype (Show, Message)

instance HasField "name" (PreparedStatementProcedure n m) PreparedStatementName where
  getField (PreparedStatementProcedure Data.PreparedStatementProcedure { name }) = name

instance (oids ~ Homotuple n Oid, Item oids ~ Oid, IsList oids) => HasField "parameterOids" (PreparedStatementProcedure n m) (Maybe oids) where
  getField (PreparedStatementProcedure Data.PreparedStatementProcedure { parameterOids }) = fromList <$> parameterOids

type instance MessageResult (PreparedStatementProcedure n m) = (PreparedStatement n m)

-- | This represents a portal which is already processed by a server.
newtype Portal (parameterLength :: Nat) (resultLength :: Nat) =
  Portal Data.Portal
  deriving newtype (Show, Eq, Close)

instance HasField "name" (Portal n m) PortalName where
  getField (Portal Data.Portal { name }) = name

-- | This represents a portal which is not yet processed by a server.
newtype PortalProcedure (parameterLength :: Nat) (resultLength :: Nat) =
  PortalProcedure Data.PortalProcedure
  deriving newtype (Show, Message)

instance HasField "name" (PortalProcedure n m) PortalName where
  getField (PortalProcedure Data.PortalProcedure { name }) = name

type instance MessageResult (PortalProcedure n m) = (PreparedStatement n m, Portal n m)

-- | This represents a result of a "Execute" message which is already processed by a server.
newtype Executed (parameterLength :: Nat) (resultLength :: Nat) r =
  Executed (Data.Executed r)
  deriving newtype (Show, Eq)

-- | To get the result of 'Executed'.
result :: Executed n m r -> ExecuteResult
result (Executed Data.Executed { result }) = result

-- | To get the records of 'Executed'.
records :: Executed n m r -> [r]
records (Executed Data.Executed { records }) = records

-- | This represents a result of a "Execute" message which is not yet processed by a server.
newtype ExecutedProcedure (parameterLength :: Nat) (resultLength :: Nat) r =
  ExecutedProcedure (Data.ExecutedProcedure r)
  deriving newtype (Show, Message)

type instance MessageResult (ExecutedProcedure n m r) = (PreparedStatement n m, Portal n m, Executed n m r, Maybe ErrorFields) -- TODO don't error fields themselves

-- | This means that @r@ has a 'name' accessor.
class HasName r where
  -- | Type of name of @r@.
  type Name r :: Type

  -- | To get a name of @r@.
  name :: r -> Name r
  default name :: HasField "name" r (Name r) => r -> Name r
  name = getField @"name"

instance HasName (PreparedStatement n m) where
  type Name (PreparedStatement n m) = PreparedStatementName

instance HasName (PreparedStatementProcedure n m) where
  type Name (PreparedStatementProcedure n m) = PreparedStatementName

instance HasName (Portal n m) where
  type Name (Portal n m) = PortalName

instance HasName (PortalProcedure n m) where
  type Name (PortalProcedure n m) = PortalName

-- | This means that @r@ has a 'parameterOids' accessor.
class HasParameterOids r a where
  -- | To get OIDs of a parameter.
  parameterOids :: r -> a
  default parameterOids :: HasField "parameterOids" r a => r -> a
  parameterOids = getField @"parameterOids"

instance (oids ~ Homotuple n Oid, Item oids ~ Oid, IsList oids) => HasParameterOids (PreparedStatement n m) oids

instance (oids ~ Homotuple n Oid, Item oids ~ Oid, IsList oids) => HasParameterOids (PreparedStatementProcedure n m) (Maybe oids)

-- Values

-- | To get the procedure to build the message of parsing SQL query and to parse its response.
parse
  :: forall plen rlen.
     ( KnownNat plen
     , KnownNat rlen
     , Item (Homotuple plen Oid) ~ Oid
     , Item (Homotuple rlen ColumnInfo) ~ ColumnInfo
     , Item (Homotuple rlen Oid) ~ Oid
     , IsList (Homotuple rlen Oid)
     , IsList (Homotuple plen Oid)
     , IsList (Homotuple rlen ColumnInfo)
     )
  => PreparedStatementName -- ^ A new name of prepared statement.
  -> Query -- ^ SQL whose placeholder style is dollar style.
  -> Maybe (Homotuple plen Oid, Homotuple rlen Oid) -- ^ On 'Nothing' an additional pair of a request and a response is necessary.
                                                    -- If concrete OIDs are given, it will be pass over.
  -> PreparedStatementProcedure plen rlen
parse name query oids =
  let
    lensOrOids =
      case oids of
        Nothing -> Left (fromInteger $ natVal (Proxy :: Proxy plen), fromInteger $ natVal (Proxy :: Proxy rlen))
        Just v  -> Right $ bimap toList toList v
  in
    PreparedStatementProcedure $ Query.parse name query lensOrOids

-- | This means that @ps@ is a objective of 'bind'.
class Bind ps where
  -- | To get the procedure to build the message of binding the parameter and to parse its response.
  bind
    :: forall rlen param m.
       ( ToRecord param
       , KnownNat rlen
       , Tuple.HasLength (Homotuple rlen ColumnInfo)
       , MonadFail m
       )
    => PortalName -- ^ A new name of portal.
    -> FormatCode -- ^ Binary format or text format for the parameter.
    -> FormatCode -- ^ Binary format or text format for the results.
    -> BackendParameters -- ^ The set of the server parameters.
    -> StringEncoder -- ^ How to encode strings.
    -> param -- ^ Parameter for this query.
    -> ps (Length param) rlen -- ^ Prepared statement.
    -> m (PortalProcedure (Length param) rlen)

instance Bind PreparedStatement where
  bind
    :: forall rlen param m.
       ( ToRecord param
       , Tuple.HasLength (Homotuple rlen ColumnInfo)
       , MonadFail m
       )
    => PortalName -> FormatCode -> FormatCode -> BackendParameters -> StringEncoder -> param -> PreparedStatement (Length param) rlen -> m (PortalProcedure (Length param) rlen)
  bind name parameterFormat resultFormat backendParams encode parameters (PreparedStatement ps) = PortalProcedure <$> Query.bind name parameterFormat resultFormat backendParams encode parameters ps

instance Bind PreparedStatementProcedure where
  bind
    :: forall rlen param m.
       ( ToRecord param
       , KnownNat rlen
       , MonadFail m
       )
    => PortalName -> FormatCode -> FormatCode -> BackendParameters -> StringEncoder -> param -> PreparedStatementProcedure (Length param) rlen -> m (PortalProcedure (Length param) rlen)
  bind name parameterFormat resultFormat backendParams encode parameters (PreparedStatementProcedure psProc) = PortalProcedure <$> Query.bind name parameterFormat resultFormat backendParams encode parameters psProc

-- | This means that @p@ is a objective of 'execute'.
class Execute p where
  -- | To get the procedure to build the message of execution and to parse its response.
  execute
    :: forall plen result.
       ( FromRecord result
       , ColumnInfo ~ Item (Homotuple (Length result) ColumnInfo)
       , IsList (Homotuple (Length result) ColumnInfo)
       )
    => Word -- ^ How many records to get. "0" means unlimited.
    -> StringDecoder -- ^ How to decode strings.
    -> p plen (Length result) -- ^ Portal.
    -> ExecutedProcedure plen (Length result) result

instance Execute Portal where
  execute rowLimit decode (Portal p) = ExecutedProcedure $ Query.execute rowLimit decode p

instance Execute PortalProcedure where
  execute rowLimit decode (PortalProcedure pProc) = ExecutedProcedure $ Query.execute rowLimit decode pProc

-- | To send @BEGIN@ SQL statement.
begin :: ExecutedProcedure 0 0 ()
begin = ExecutedProcedure Query.begin

-- | To send @COMMIT@ SQL statement.
commit :: ExecutedProcedure 0 0 ()
commit = ExecutedProcedure Query.commit

-- | To send @ROLLBACK@ SQL statement.
rollback :: ExecutedProcedure 0 0 ()
rollback = ExecutedProcedure Query.rollback
