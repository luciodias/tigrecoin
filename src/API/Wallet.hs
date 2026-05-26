{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Wallet where

import Control.Monad.IO.Class (liftIO)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.Time.Clock (getCurrentTime)
import Data.UUID (UUID)
import Data.UUID.V4 (nextRandom)
import Servant (ServerT, (:>), (:<|>)(..), Get, Post, ReqBody, JSON, NoContent)

import Types.AppM (AppM, throwAppError, getPool)
import Types.Errors (AppError(..))
import Auth.Middleware (AuthUser(..))
import Database.Queries.Wallet qualified as QWallet
import Database.Queries.Transaction qualified as QTxn
import Models.Wallet (Wallet(..), WalletId(..), WalletResponse(..), DepositRequest(..), WithdrawRequest(..), toWalletResponse)
import Models.Transaction (Transaction(..), TransactionId(..), TransactionType(..))

import qualified Data.Text as T
import qualified Data.UUID as UUID

type WalletAPI =
  "wallet" :> (
       Get  '[JSON] WalletResponse
  :<|> "deposit"  :> ReqBody '[JSON] DepositRequest  :> Post '[JSON] WalletResponse
  :<|> "withdraw" :> ReqBody '[JSON] WithdrawRequest :> Post '[JSON] WalletResponse
  )

walletServer :: AuthUser -> ServerT WalletAPI AppM
walletServer authUser = getWallet authUser :<|> deposit authUser :<|> withdraw authUser

uuidFromText :: Text -> UUID
uuidFromText t = case UUID.fromText t of
  Just u  -> u
  Nothing -> error $ "Invalid UUID: " <> T.unpack t

getWallet :: AuthUser -> AppM WalletResponse
getWallet authUser = do
  pool <- getPool
  let uid = uuidFromText (auUserId authUser)
  mWallet <- liftIO $ withResource pool $ \conn ->
    QWallet.findWalletByUserId conn uid
  case mWallet of
    Nothing   -> throwAppError $ NotFound "Wallet not found"
    Just w    -> pure $ toWalletResponse w

deposit :: AuthUser -> DepositRequest -> AppM WalletResponse
deposit authUser req = do
  pool <- getPool
  now <- liftIO getCurrentTime
  txnId <- liftIO nextRandom
  let uid = uuidFromText (auUserId authUser)
  mWallet <- liftIO $ withResource pool $ \conn ->
    QWallet.findWalletByUserId conn uid
  case mWallet of
    Nothing -> throwAppError $ NotFound "Wallet not found"
    Just w  -> do
      liftIO $ withResource pool $ \conn -> do
        QWallet.updateBalance conn (unWalletId $ walletId w) (depAmount req)
        let txn = Transaction
              { txnId          = TransactionId txnId
              , txnWalletId    = unWalletId $ walletId w
              , txnType        = Deposit
              , txnAmount      = depAmount req
              , txnDescription = "Deposit"
              , txnCreatedAt   = now
              }
        QTxn.insertTransaction conn txn
      getWallet authUser

withdraw :: AuthUser -> WithdrawRequest -> AppM WalletResponse
withdraw authUser req = do
  pool <- getPool
  now <- liftIO getCurrentTime
  txnId <- liftIO nextRandom
  let uid = uuidFromText (auUserId authUser)
  mWallet <- liftIO $ withResource pool $ \conn ->
    QWallet.findWalletByUserId conn uid
  case mWallet of
    Nothing -> throwAppError $ NotFound "Wallet not found"
    Just w  -> do
      liftIO $ withResource pool $ \conn -> do
        QWallet.updateBalance conn (unWalletId $ walletId w) (- (witAmount req))
        let txn = Transaction
              { txnId          = TransactionId txnId
              , txnWalletId    = unWalletId $ walletId w
              , txnType        = Withdrawal
              , txnAmount      = witAmount req
              , txnDescription = "Withdrawal"
              , txnCreatedAt   = now
              }
        QTxn.insertTransaction conn txn
      getWallet authUser
