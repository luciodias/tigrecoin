{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Transaction where

import Control.Monad.IO.Class (liftIO)
import Data.Maybe (fromMaybe)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.UUID (UUID)
import Servant (ServerT, (:>), (:<|>)(..), Get, QueryParam, JSON, Capture)

import Types.AppM (AppM, throwAppError, getPool)
import Types.Errors (AppError(..))
import Auth.Middleware (AuthUser(..))
import Database.Queries.Transaction qualified as QTxn
import Database.Queries.Wallet qualified as QWallet
import Models.Transaction (Transaction(..), TransactionResponse(..), toTransactionResponse)
import Models.Wallet (Wallet(..), WalletId(..))

import qualified Data.Text as T
import qualified Data.UUID as UUID

type TransactionAPI =
  "transactions" :> (
       QueryParam "page" Int
    :> QueryParam "per_page" Int
    :> Get '[JSON] [TransactionResponse]
  :<|> Capture "id" UUID :> Get '[JSON] TransactionResponse
  )

transactionServer :: AuthUser -> ServerT TransactionAPI AppM
transactionServer authUser = listTransactions authUser :<|> getTransaction authUser

uuidFromText :: Text -> UUID
uuidFromText t = case UUID.fromText t of
  Just u  -> u
  Nothing -> error $ "Invalid UUID: " <> T.unpack t

listTransactions :: AuthUser -> Maybe Int -> Maybe Int -> AppM [TransactionResponse]
listTransactions authUser mPage mPerPage = do
  pool <- getPool
  let limit  = fromMaybe 50 mPerPage
      offset = fromMaybe 0 ((subtract 1) <$> mPage) * limit
      uid = uuidFromText (auUserId authUser)
  mWallet <- liftIO $ withResource pool $ \conn ->
    QWallet.findWalletByUserId conn uid
  case mWallet of
    Nothing -> pure []
    Just w  -> do
      txns <- liftIO $ withResource pool $ \conn ->
        QTxn.listTransactions conn (Just $ unWalletId $ walletId w) (Just limit) (Just offset)
      pure $ map toTransactionResponse txns

getTransaction :: AuthUser -> UUID -> AppM TransactionResponse
getTransaction authUser txnId = do
  pool <- getPool
  mTxn <- liftIO $ withResource pool $ \conn -> QTxn.findTransactionById conn txnId
  case mTxn of
    Nothing   -> throwAppError $ NotFound "Transaction not found"
    Just txn  -> pure $ toTransactionResponse txn
