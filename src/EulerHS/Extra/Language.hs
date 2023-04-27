{- |
Module      :  EulerHS.Extra.Language
Copyright   :  (C) Juspay Technologies Pvt Ltd 2019-2022
License     :  Apache 2.0 (see the file LICENSE)
Maintainer  :  opensource@juspay.in
Stability   :  experimental
Portability :  non-portable

This module contains additional methods and functions providing extra functionality
over the stok ones.

This is an internal module. Import `EulerHS.Language` instead.
-}

module EulerHS.Extra.Language
  ( getOrInitSqlConn
  , getOrInitKVDBConn
  , rExpire
  , rExpireB
  , rDel
  , rDelB
  , rExists
  , rExistsB
  , rExistsT -- alias for rExists (back compat)
  , rHget
  , rHgetB
  , rHset
  , rHsetB
  , rIncr
  , rIncrB
  , rSet
  , rSetT  -- alias for rSet (back compat)
  , rSetB
  , rGet
  , rGetB
  , rGetT  -- alias for rGet (back compat)
  , rSetex
  , rSetexB
  , rSetexT  -- alias for rSetex (back compat)
  , rSetOpts
  , rSetOptsB
  , rSetOptsT
  , keyToSlot
  , rSadd
  , rSismember
  , updateLoggerContext
  , withLoggerContext
  ) where

import           EulerHS.Prelude hiding (get, id)

import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text.Encoding as TE
import           Database.Redis (keyToSlot)
import qualified EulerHS.Core.KVDB.Language as L
import qualified EulerHS.Core.Types as T
import qualified EulerHS.Framework.Language as L
import           EulerHS.Runtime (CoreRuntime (..), FlowRuntime (..),
                                  LoggerRuntime (..))

type RedisName = Text
type TextKey = Text
type TextField = Text
type ByteKey = ByteString
type ByteField = ByteString
type ByteValue = ByteString

-- | Get existing SQL connection, or init a new connection.
getOrInitSqlConn :: (HasCallStack, L.MonadFlow m) =>
  T.DBConfig beM -> m (T.DBResult (T.SqlConn beM))
getOrInitSqlConn cfg = do
  eConn <- L.getSqlDBConnection cfg
  case eConn of
    Left (T.DBError T.ConnectionDoesNotExist _) -> L.initSqlDBConnection cfg
    res                                         -> pure res

-- | Get existing Redis connection, or init a new connection.
getOrInitKVDBConn :: (HasCallStack, L.MonadFlow m) => T.KVDBConfig -> m (T.KVDBAnswer T.KVDBConn)
getOrInitKVDBConn cfg = do
  conn <- L.getKVDBConnection cfg
  case conn of
    Left (T.KVDBError T.KVDBConnectionDoesNotExist _) -> L.initKVDBConnection cfg
    res -> pure res

-- KVDB convenient functions

-- ----------------------------------------------------------------------------

-- | Set a key's time to live in seconds.
-- Key is a text string.
--
-- mtl version of the original function.
rExpire :: (HasCallStack, Integral t, L.MonadFlow m) =>
  RedisName -> TextKey -> t -> m (Either T.KVDBReply Bool)
rExpire cName k t = rExpireB cName (TE.encodeUtf8 k) t

-- | Set a key's time to live in seconds.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rExpireB :: (HasCallStack, Integral t, L.MonadFlow m) =>
  RedisName -> ByteKey -> t -> m (Either T.KVDBReply Bool)
rExpireB cName k t = do
  res <- L.runKVDB cName $ L.expire k $ toInteger t
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis expire" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis expire" $ show err
      pure res

-- ----------------------------------------------------------------------------

-- | Delete a keys.
-- Key is a text string.
--
-- mtl version of the original function.
rDel :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> [TextKey] -> m (Either T.KVDBReply Integer)
rDel cName ks = rDelB cName (TE.encodeUtf8 <$> ks)

-- | Delete a keys.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rDelB :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> [ByteKey] -> m (Either T.KVDBReply Integer)
rDelB cName ks = do
  res <- L.runKVDB cName $ L.del ks
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis del" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis del" $ show err
      pure res

-- ----------------------------------------------------------------------------

-- | Determine if a key exists.
-- Key is a text string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rExists :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> TextKey -> m (Either T.KVDBReply Bool)
rExists cName k = rExistsB cName $ TE.encodeUtf8 k

-- | Determine if a key exists.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rExistsB :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> ByteKey -> m (Either T.KVDBReply Bool)
rExistsB cName k = do
  res <- L.runKVDB cName $ L.exists k
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis exists" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis exists" $ show err
      pure res

-- | Determine if a key exists.
-- Key is a text string.
--
-- mtl version of the original function.
rExistsT :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> TextKey -> m (Either T.KVDBReply Bool)
rExistsT = rExists

-- ----------------------------------------------------------------------------

-- | Get the value of a hash field.
-- Key is a text string.
--
-- Performs decodings of the value.
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rHget :: (HasCallStack, FromJSON v, L.MonadFlow m)
  => RedisName -> TextKey -> TextField -> m (Maybe v)
rHget cName k f = do
  let k' = TE.encodeUtf8 k
  let f' = TE.encodeUtf8 f
  r <- L.runKVDB cName $ L.hget k' f'
  case r of
    Right (Just val) -> do
      let v = A.eitherDecode $ BSL.fromStrict val
      case v of
        Left err -> do
          L.logError @Text "Decoding error: " $ show err
          pure Nothing
        Right v' -> do
          -- L.logDebug @Text "Decoded value" $ show v'
          pure $ Just v'
    Right Nothing -> pure Nothing
    Left err -> do
      L.logError @Text "Redis rHget" $ show err
      pure Nothing

-- | Get the value of a hash field.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rHgetB :: (HasCallStack, L.MonadFlow m) =>
  Text -> ByteKey -> ByteField -> m (Maybe ByteValue)
rHgetB cName k f = do
  res <- L.runKVDB cName $ L.hget k f
  case res of
    Right (Just val) -> pure $ Just val
    Right Nothing -> pure Nothing
    Left err -> do
      L.logError @Text "Redis hget" $ show err
      pure Nothing

-- ----------------------------------------------------------------------------

-- | Set the value of a hash field.
-- Key is a text string.
--
-- mtl version of the original function.
rHset :: (HasCallStack, ToJSON v, L.MonadFlow m)
  => RedisName -> TextKey -> TextField -> v -> m (Either T.KVDBReply Integer)
rHset cName k f v = rHsetB cName k' f' v'
  where
    k' = TE.encodeUtf8 k
    f' = TE.encodeUtf8 f
    v' = BSL.toStrict $ A.encode v

-- | Set the value of a hash field.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rHsetB :: (HasCallStack, L.MonadFlow m)
  => RedisName -> ByteKey -> ByteField -> ByteValue -> m (Either T.KVDBReply Integer)
rHsetB cName k f v = do
  res <- L.runKVDB cName $
    L.hset k f v
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis hset" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis hset" $ show err
      pure res

-- ----------------------------------------------------------------------------

-- | Increment the integer value of a key by one.
-- Key is a text string.
--
-- mtl version of the original function.
rIncr :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> TextKey -> m (Either T.KVDBReply Integer)
rIncr cName k = rIncrB cName (TE.encodeUtf8 k)

-- | Increment the integer value of a key by one.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rIncrB :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> ByteKey -> m (Either T.KVDBReply Integer)
rIncrB cName k = do
  res <- L.runKVDB cName $ L.incr k
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis incr" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis incr" $ show err
      pure res

-- ----------------------------------------------------------------------------

-- | Set the value of a key.
-- Key is a text string.
--
-- mtl version of the original function.
rSet :: (HasCallStack, ToJSON v, L.MonadFlow m) =>
  RedisName -> TextKey -> v -> m (Either T.KVDBReply T.KVDBStatus)
rSet cName k v = rSetB cName k' v'
  where
    k' = TE.encodeUtf8 k
    v' = BSL.toStrict $ A.encode v

-- | Set the value of a key.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rSetB :: (HasCallStack, L.MonadFlow m) =>
  Text -> ByteKey -> ByteValue -> m (Either T.KVDBReply T.KVDBStatus)
rSetB cName k v = do
  res <- L.runKVDB cName $ L.set k v
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis set" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis set" $ show err
      pure res

-- | Set the value of a key.
-- Key is a text string.
--
-- mtl version of the original function.
rSetT :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> TextKey -> Text -> m (Either T.KVDBReply T.KVDBStatus)
rSetT cName k v = rSetB cName k' v'
  where
    k' = TE.encodeUtf8 k
    v' = TE.encodeUtf8 v

-- ----------------------------------------------------------------------------

-- | Get the value of a key.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rGetB :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> ByteKey -> m (Maybe ByteValue) -- Binary.decode?
rGetB cName k = do
  mv <- L.runKVDB cName $ L.get k
  case mv of
    Right mval -> pure mval
    Left err -> do
      L.logError @Text "Redis get" $ show err
      pure Nothing

-- | Get the value of a key.
-- Key is a text string.
--
-- Performs encodings of the value.
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rGet :: (HasCallStack, FromJSON v, L.MonadFlow m) =>
  RedisName -> TextKey -> m (Maybe v)
rGet cName k = do
  mv <- rGetB cName (TE.encodeUtf8 k)
  case mv of
    Just val -> case A.eitherDecode' $ BSL.fromStrict val of
      Left err -> do
        L.logError @Text "Redis rGet json decodeEither error" $ show err
        pure Nothing
      Right resp -> pure $ Just resp
    Nothing -> pure Nothing

-- | Get the value of a key.
-- Key is a text string.
--
-- mtl version of the original function.
rGetT :: (HasCallStack, L.MonadFlow m) =>
  Text -> Text -> m (Maybe Text)
rGetT cName k = do
  mv <- rGetB cName (TE.encodeUtf8 k)
  case mv of
    Just val ->
      case TE.decodeUtf8' val of
        Left err -> do
          L.logError @Text "Redis rGetT unicode decode error" (show err)
          pure Nothing
        Right x ->
          pure $ Just x
    Nothing -> pure Nothing

-- ----------------------------------------------------------------------------

-- | Set the value and ttl of a key.
-- Key is a text string.
--
-- Performs encodings of the key and value.
-- mtl version of the original function.
rSetex :: (HasCallStack, ToJSON v, Integral t, L.MonadFlow m) =>
  RedisName -> TextKey -> v -> t -> m (Either T.KVDBReply T.KVDBStatus)
rSetex cName k v t = rSetexB cName k' v' t
  where
    k' = TE.encodeUtf8 k
    v' = BSL.toStrict $ A.encode v

-- | Set the value and ttl of a key.
-- Key is a byte string.
--
-- mtl version of the original function.
-- Additionally, logs the error may happen.
rSetexB :: (HasCallStack, Integral t, L.MonadFlow m) =>
  RedisName -> ByteKey -> ByteValue -> t -> m (Either T.KVDBReply T.KVDBStatus)
rSetexB cName k v t = do
  res <- L.runKVDB cName $ L.setex k (toInteger t) v
  case res of
    Right _ -> do
      -- L.logInfo @Text "Redis setex" $ show r
      pure res
    Left err -> do
      L.logError @Text "Redis setex" $ show err
      pure res

-- | Set the value and ttl of a key.
-- Key is a text string.
--
-- mtl version of the original function.
rSetexT :: (HasCallStack, ToJSON v, Integral t, L.MonadFlow m) =>
  RedisName -> TextKey -> v -> t -> m (Either T.KVDBReply T.KVDBStatus)
rSetexT = rSetex

-- ----------------------------------------------------------------------------

rSetOpts
  :: (HasCallStack, ToJSON v, L.MonadFlow m)
  => RedisName
  -> TextKey
  -> v
  -> L.KVDBSetTTLOption
  -> L.KVDBSetConditionOption
  -> m (Either T.KVDBReply Bool)
rSetOpts cName k v ttl cond = rSetOptsB cName k' v' ttl cond
  where
    k' = TE.encodeUtf8 k
    v' = BSL.toStrict $ A.encode v

rSetOptsB
  :: (HasCallStack, L.MonadFlow m)
  => RedisName
  -> ByteKey
  -> ByteValue
  -> L.KVDBSetTTLOption
  -> L.KVDBSetConditionOption
  -> m (Either T.KVDBReply Bool)
rSetOptsB cName k v ttl cond = do
  res <- L.runKVDB cName $ L.setOpts k v ttl cond
  case res of
    Right _ -> pure res
    Left err -> do
      L.logError @Text "Redis setOpts" $ show err
      pure res

rSetOptsT
  :: (HasCallStack, L.MonadFlow m)
  => RedisName
  -> TextKey
  -> Text
  -> L.KVDBSetTTLOption
  -> L.KVDBSetConditionOption
  -> m (Either T.KVDBReply Bool)
rSetOptsT cName k v ttl cond = rSetOptsB cName k' v' ttl cond
  where
    k' = TE.encodeUtf8 k
    v' = TE.encodeUtf8 v

-- ------------------------------------------------------------------------------

rSadd :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> L.KVDBKey -> [L.KVDBValue] -> m (Either T.KVDBReply Integer)
rSadd cName k v = do
  res <- L.runKVDB cName $ L.sadd k v
  case res of
    Right _ -> pure res
    Left err -> do
      L.logError @Text "Redis sadd" $ show err
      pure res

rSismember :: (HasCallStack, L.MonadFlow m) =>
  RedisName -> L.KVDBKey -> L.KVDBValue -> m (Either T.KVDBReply Bool)
rSismember cName k v = do
  res <- L.runKVDB cName $ L.sismember k v
  case res of
    Right _ -> pure res
    Left err -> do
      L.logError @Text "Redis sismember" $ show err
      pure res

withLoggerContext :: (HasCallStack, L.MonadFlow m) => (T.LogContext -> T.LogContext) -> L.Flow a -> m a
withLoggerContext updateLCtx = L.withModifiedRuntime (updateLoggerContext updateLCtx)


updateLoggerContext :: HasCallStack => (T.LogContext -> T.LogContext) -> FlowRuntime -> FlowRuntime
updateLoggerContext updateLCtx rt@FlowRuntime{..} = rt {_coreRuntime = _coreRuntime {_loggerRuntime = newLrt}}
  where
    newLrt :: LoggerRuntime
    newLrt = case _loggerRuntime _coreRuntime of
               MemoryLoggerRuntime a lc b c d -> MemoryLoggerRuntime a (updateLCtx lc) b c d
               LoggerRuntime { _flowFormatter, _logContext, _logLevel, _logRawSql, _logCounter, _logMaskingConfig, _logLoggerHandle}
                 -> LoggerRuntime  _flowFormatter (updateLCtx _logContext) _logLevel _logRawSql _logCounter _logMaskingConfig _logLoggerHandle
