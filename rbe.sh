source build/envsetup.sh
source build/make/rbesetup.sh  

export RBE_service="unix:///mnt/ephemeral/buildbarn/.cache/bb_clientd/grpc" 
export RBE_use_application_default_credentials="false" 
export RBE_use_rpc_credentials="false" 
 
# export RBE_tls_client_auth_cert="/mosaic/engflow.crt" 
# export RBE_tls_client_auth_key="/mosaic/engflow.key" 
 
export USE_RBE="1" 
export NINJA_REMOTE_NUM_JOBS="500" 
export WORKER_POOL="default" 
 
export RBE_ABI_DUMPER="1" 
export RBE_ABI_DUMPER_EXEC_STRATEGY="remote_local_fallback" 
export RBE_ABI_DUMPER_POOL="$WORKER_POOL" 
export RBE_ABI_LINKER="1" 
export RBE_ABI_LINKER_EXEC_STRATEGY="remote_local_fallback" 
export RBE_ABI_LINKER_POOL="$WORKER_POOL" 
export RBE_CLANG_TIDY="1" 
export RBE_CLANG_TIDY_EXEC_STRATEGY="remote_local_fallback" 
export RBE_CLANG_TIDY_POOL="$WORKER_POOL" 
export RBE_CXX="1" 
export RBE_CXX_EXEC_STRATEGY="remote_local_fallback" 
export RBE_CXX_POOL="$WORKER_POOL" 
export RBE_CXX_LINKS="1" # changed from 0 
export RBE_CXX_LINKS_EXEC_STRATEGY="remote_local_fallback"
export RBE_CXX_LINKS_STRATEGY="remote_local_fallback"
export RBE_CXX_LINKS_POOL="$WORKER_POOL"
export RBE_D8="1" 
export RBE_D8_EXEC_STRATEGY="remote_local_fallback" 
export RBE_D8_POOL="$WORKER_POOL" 
export RBE_JAR="1" 
export RBE_JAR_EXEC_STRATEGY="remote_local_fallback" 
export RBE_JAR_POOL="$WORKER_POOL" 
export RBE_JAVA="1" 
export RBE_JAVA_POOL="$WORKER_POOL" 
export RBE_JAVAC="1" 
export RBE_JAVAC_EXEC_STRATEGY="remote_local_fallback" 
export RBE_JAVAC_POOL="$WORKER_POOL" 
export RBE_METALAVA="0" 
export RBE_METALAVA_POOL="$WORKER_POOL" 
export RBE_R8="1" 
export RBE_R8_EXEC_STRATEGY="remote_local_fallback" 
export RBE_R8_POOL="$WORKER_POOL" 
export RBE_SIGNAPK="1" 
export RBE_SIGNAPK_EXEC_STRATEGY="remote_local_fallback" 
export RBE_SIGNAPK_POOL="$WORKER_POOL" 
export RBE_TURBINE="1" 
export RBE_TURBINE_EXEC_STRATEGY="remote_local_fallback" 
export RBE_TURBINE_POOL="$WORKER_POOL" 
export RBE_ZIP="1" 
export RBE_ZIP_EXEC_STRATEGY="remote_local_fallback" 
export RBE_ZIP_POOL="$WORKER_POOL" 
 
export RBE_instance="default" 
export RBE_DIR="prebuilts/remoteexecution-client/live" 
export RBE_server_address="unix:///tmp/reproxy.sock" 
export RBE_service_no_auth="true" 
 
export RBE_enable_deps_cache="true" 
export RBE_cache_dir="$HOME/.cache/reclient/cache" 
mkdir -p $RBE_cache_dir 
 
export RBE_v=4
export RBE_alsologtostderr=true 
 
# OPTIONAL: Skip downloading object files. 
# export RBE_download_regex="-.*\\.o" 
