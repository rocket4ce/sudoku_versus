defmodule SudokuVersus.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :email, :string
      add :display_name, :string
      add :avatar_url, :string

      # Authentication
      add :password_hash, :string
      add :is_guest, :boolean, default: false, null: false

      # OAuth
      add :oauth_provider, :string
      add :oauth_provider_id, :string

      # Statistics (denormalized for performance)
      add :total_games_played, :integer, default: 0, null: false
      add :total_puzzles_completed, :integer, default: 0, null: false
      add :total_points_earned, :integer, default: 0, null: false
      add :highest_score, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create unique_index(:users, [:oauth_provider, :oauth_provider_id])
    create index(:users, [:total_points_earned])
  end
end
