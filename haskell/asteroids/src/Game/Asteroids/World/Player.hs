module Game.Asteroids.World.Player(
    Player(..)
  , playerSize
  , playerCollideRadius
  , playerMass
  , playerThrust
  , playerRotateSpeed
  , spawnPlayer
  , rotatePlayer
  , addPlayerVelocity
  , killPlayer
  ) where

import Apecs
import Control.Monad.IO.Class
import Game.Asteroids.World.Mass
import Game.Asteroids.World.Position
import Game.Asteroids.World.Rotation
import Game.Asteroids.World.Size
import Game.Asteroids.World.Velocity
import Linear

data Player = Player

instance Component Player
  where type Storage Player = Unique Player

-- | Player size in pixels (1 px == 1 meter)
playerSize :: V2 Float
playerSize = V2 30 25

-- | Collision radius for player
playerCollideRadius :: Float
playerCollideRadius = 25

-- | Player mass in kg
playerMass :: Float
playerMass = 1000

-- | Force in Newtons
playerThrust :: Float
playerThrust = 100000

-- | Rotation speed in radians per second
playerRotateSpeed :: Float
playerRotateSpeed = pi

spawnPlayer :: (MonadIO m
  , Has w m WorldWidth
  , Has w m WorldHeight
  , Has w m Player
  , Has w m Mass
  , Has w m Position
  , Has w m Rotation
  , Has w m Velocity
  , Has w m EntityCounter
  ) => SystemT w m Entity
spawnPlayer = do
  ws <- getWorldSize
  newEntity (Player, Mass playerMass, Position (ws * 0.5), Rotation 0, Velocity 0)

-- | Rotate player to given amount of radians
rotatePlayer :: (MonadIO m
  , Has w m Player
  , Has w m Rotation
  ) => Float -> SystemT w m ()
rotatePlayer a = cmap $ \(Player, Rotation r) -> (Player, Rotation $ clamp $ r+a)
  where
    clamp a | a < 0     = 2*pi + a
            | a > 2*pi  = a - 2*pi
            | otherwise = a
    {-# INLINE clamp #-}
{-# INLINE rotatePlayer #-}

-- | Add velocity alonside player facing angle
addPlayerVelocity :: (MonadIO m
  , Has w m Player
  , Has w m Velocity
  , Has w m Rotation
  ) => Float -- ^ Velocity
  -> SystemT w m ()
addPlayerVelocity dv = cmap $ \(Player, Velocity v, Rotation r) -> (Player, Velocity $ v + V2 (dv * cos r) (dv * sin r))
{-# INLINE addPlayerVelocity #-}

-- | Destroy player entity
killPlayer :: (MonadIO m
  , Has w m Player
  , Has w m Mass
  , Has w m Position
  , Has w m Rotation
  , Has w m Velocity
  ) => SystemT w m ()
killPlayer = cmapM_ $ \(Player, e) -> destroy e (Proxy :: Proxy (Player, Mass, Position, Rotation, Velocity))
