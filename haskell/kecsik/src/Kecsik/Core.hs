module Kecsik.Core(
    Entity(..)
  , World(..)
  , newWorld
  , SystemT
  , System
  , runSystemT
  , execSystemT
  , Component(..)
  , IsStorage(..)
  ) where

import Control.Monad.Reader
import GHC.Generics (Generic)
import Data.Mutable

newtype Entity = Entity { unEntity :: Int }
  deriving (Generic, Show, Read, Eq, Ord, Num)

data World cs = World {
-- | Entity counter that defines id of next new entity
  worldCounter  :: !Int
-- | Components storage
, worldStorage  :: !(Storage cs)
} deriving (Generic)

instance Mutable s (Storage cs) => Mutable s (World cs) where
  type Ref s (World cs) = GRef s (World cs)

newWorld :: (MonadIO m, Component cs) => m (World cs)
newWorld = World
  <$> pure 0
  <*> newStorage

newtype SystemT cs m a = SystemT { unSystemT :: ReaderT (Ref (PrimState m) (World cs)) m a }
  deriving (Functor, Monad, Applicative)

type System cs a = SystemT cs IO

runSystemT :: SystemT cs m a -> Ref (PrimState m) (World cs) -> m a
runSystemT ma w = runReaderT (unSystemT ma) w

execSystemT :: (Monad m, Mutable (PrimState m) (Storage cs), PrimMonad m) => SystemT cs m a -> World cs -> m (a, World cs)
execSystemT ma w = do
  wr <- thawRef w
  a <- runSystemT ma wr
  w' <- freezeRef wr
  pure (a, w')

execSystemT_ :: (Monad m, Mutable (PrimState m) (Storage cs), PrimMonad m) => SystemT cs m a -> World cs -> m a
execSystemT_ ma w = runSystemT ma =<< thawRef w

class IsStorage (Storage a) => Component a where
  type Storage a :: *

class IsStorage a where
  newStorage :: MonadIO m => m a
