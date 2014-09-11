# encoding: utf-8
module IeducarApi
  class Base
    class ApiError < Exception; end

    attr_accessor :url, :access_key, :secret_key, :unity_id

    def initialize(options = {})
      self.url = options.delete(:url)
      self.access_key = options.delete(:access_key)
      self.secret_key = options.delete(:secret_key)
      self.unity_id = options.delete(:unity_id)

      raise ApiError.new("É necessário informar a url de acesso: url") if url.blank?
      raise ApiError.new("É necessário informar a chave de acesso: access_key") if access_key.blank?
      raise ApiError.new("É necessário informar a chave secreta: secret_key") if secret_key.blank?
      raise ApiError.new("É necessário informar o id da unidade: unity_id") if unity_id.blank?
    end

    def fetch(params = {})
      params.reverse_merge!(:oper => "get")

      raise ApiError.new("É necessário informar o caminho de acesso: path") if params[:path].blank?
      raise ApiError.new("É necessário informar o recurso de acesso: resource") if params[:resource].blank?

      endpoint = [url, params[:path]].join("/")

      result = RestClient.get endpoint, {
        params: {
          access_key: access_key,
          secret_key: secret_key,
          instituicao_id: unity_id,
          oper: params[:oper],
          resource: params[:resource]
        }
      }
      result = JSON.parse(result)

      if result["any_error_msg"]
        raise ApiError.new(result["msgs"].map { |r| r["msg"] }.join(", "))
      end

      result
    end
  end
end
