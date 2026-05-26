{-# LANGUAGE OverloadedStrings #-}

module Database.Queries.Wallet where

import Control.Monad (void)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection, Only(..), query, execute)

import Models.Wallet (Wallet(..), WalletId(..))

findWalletByUserId :: Connection -> UUID -> IO (Maybe Wallet)
findWalletByUserId conn uid = do
  wallets <- query conn
    "SELECT id, user_id, balance, created_at, updated_at FROM wallets WHERE user_id = ?"
    (Only uid)
  pure $ case wallets of
    (w:_) -> Just w
    []    -> Nothing

findWalletById :: Connection -> UUID -> IO (Maybe Wallet)
findWalletById conn wid = do
  wallets <- query conn
    "SELECT id, user_id, balance, created_at, updated_at FROM wallets WHERE id = ?"
    (Only wid)
  pure $ case wallets of
    (w:_) -> Just w
    []    -> Nothing

insertWallet :: Connection -> Wallet -> IO ()
insertWallet conn wallet = void $ execute conn
  "INSERT INTO wallets (id, user_id, balance) VALUES (?, ?, ?)"
  (walletId wallet, walletUserId wallet, walletBalance wallet)

updateBalance :: Connection -> UUID -> Double -> IO ()
updateBalance conn wid amount = void $ execute conn
  "UPDATE wallets SET balance = balance + ?, updated_at = NOW() WHERE id = ?"
  (amount, wid)
