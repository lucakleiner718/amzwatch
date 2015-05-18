class ProxiesController < InheritedResources::Base

  private

    def proxy_params
      params.require(:proxy).permit(:ip, :port, :username, :password, :status, :hit_count, :failure_count)
    end
end

