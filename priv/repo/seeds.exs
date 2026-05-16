if System.get_env("LOAD_DEMO") in ["1", "true", "TRUE"] do
  StreamGenome.Demo.load!()
else
  IO.puts("Skipping demo lore seed. Set LOAD_DEMO=true to load demo data.")
end
