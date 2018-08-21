--SERVER HML: NOME_SERVIDOR_HML
--SERVER PRE: NOME_SERVIDOR_PRE
--SERVER PRD: NOME_SERVIDOR_PRD

--CRIAR VARIÁVEIS DE AMBIENTE

/*
SELECT VRB.name, VRB.value
FROM			SSISDB.internal.folders					AS FOL WITH (NOLOCK)
INNER JOIN		SSISDB.internal.environments			AS ENV WITH (NOLOCK) ON ENV.folder_id		= FOL.folder_id
INNER JOIN		SSISDB.internal.environment_variables	AS VRB WITH (NOLOCK) ON VRB.environment_id	= ENV.environment_id
WHERE	FOL.name				= 'NOME_PASTA'
	AND ENV.environment_name	= 'NOME_AMBIENTE'
	AND VRB.name				IN ( 'Variavel01'
									,'Variavel02')
ORDER BY VRB.name


SELECT	 PAR.object_type
		,FOL.name					AS folder_name
		,PRO.name					AS project_name
		,PAR.parameter_name
		,PAR.default_value
		,PAR.object_name
		,PAR.value_type
		,PAR.parameter_data_type
FROM		SSISDB.internal.object_parameters	AS PAR WITH (NOLOCK)
INNER JOIN	SSISDB.internal.projects			AS PRO WITH (NOLOCK)	ON	PRO.project_id				= PAR.project_id
INNER JOIN	SSISDB.internal.folders				AS FOL WITH (NOLOCK)	ON	FOL.folder_id				= PRO.folder_id
INNER JOIN (SELECT	 VER.object_id
					,MAX(VER.object_version_lsn) AS max_object_version_lsn
			FROM SSISDB.internal.object_versions AS VER WITH (NOLOCK)
			WHERE restored_by IS NULL
			GROUP BY VER.object_id)				AS VER					ON	VER.object_id				= PRO.project_id
																		AND VER.max_object_version_lsn	= PAR.project_version_lsn
WHERE	PRO.name			= 'PROJETO_NOME'
	AND PAR.parameter_name NOT LIKE 'CM.%'
	AND PAR.value_type = 'V'
ORDER BY PAR.object_name
		,PAR.parameter_name
*/

DECLARE @var sql_variant

SELECT @var = CASE @@SERVERNAME
				WHEN 'NOME_SERVIDOR_HML' THEN N'Valor_Variavel_HML'
				WHEN 'NOME_SERVIDOR_PRE' THEN N'Valor_Variavel_PRE'
				WHEN 'NOME_SERVIDOR_PRD' THEN N'Valor_Variavel_PRD'
			  END

IF NOT EXISTS(	SELECT 1 FROM	SSISDB.internal.folders					AS FOL WITH (NOLOCK)
				INNER JOIN		SSISDB.internal.environments			AS ENV WITH (NOLOCK) ON ENV.folder_id		= FOL.folder_id
				INNER JOIN		SSISDB.internal.environment_variables	AS VRB WITH (NOLOCK) ON VRB.environment_id	= ENV.environment_id
				WHERE	FOL.name				= 'NOME_PASTA'
					AND ENV.environment_name	= 'NOME_AMBIENTE'
					AND VRB.name				= 'Variavel01')
	BEGIN
		EXEC [SSISDB].[catalog].[create_environment_variable]
		 @variable_name				= N'Variavel01'
		,@sensitive					= False
		,@description				= N''
		,@environment_name			= N'NOME_AMBIENTE'
		,@folder_name				= N'NOME_PASTA'
		,@value						= @var
		,@data_type					= N'String'
	END
ELSE
	BEGIN
		EXEC [SSISDB].[catalog].[set_environment_variable_value]
		 @variable_name				= N'Variavel01'
		,@environment_name			= N'NOME_AMBIENTE'
		,@folder_name				= N'NOME_PASTA'
		,@value						= @var
	END

SELECT @var = CASE @@SERVERNAME
				WHEN 'NOME_SERVIDOR_HML' THEN 1
				WHEN 'NOME_SERVIDOR_PRE' THEN 2
				WHEN 'NOME_SERVIDOR_PRD' THEN 3
			  END

IF NOT EXISTS(	SELECT 1 FROM	SSISDB.internal.folders					AS FOL WITH (NOLOCK)
				INNER JOIN		SSISDB.internal.environments			AS ENV WITH (NOLOCK) ON ENV.folder_id		= FOL.folder_id
				INNER JOIN		SSISDB.internal.environment_variables	AS VRB WITH (NOLOCK) ON VRB.environment_id	= ENV.environment_id
				WHERE	FOL.name				= 'NOME_PASTA'
					AND ENV.environment_name	= 'NOME_AMBIENTE'
					AND VRB.name				= 'Variavel02')
	BEGIN
		EXEC [SSISDB].[catalog].[create_environment_variable]
		 @variable_name				= N'Variavel02'
		,@sensitive					= False
		,@description				= N''
		,@environment_name			= N'NOME_AMBIENTE'
		,@folder_name				= N'NOME_PASTA'
		,@value						= @var
		,@data_type					= N'Int32'
	END
ELSE
	BEGIN
		EXEC [SSISDB].[catalog].[set_environment_variable_value]
		 @variable_name				= N'Variavel02'
		,@environment_name			= N'NOME_AMBIENTE'
		,@folder_name				= N'NOME_PASTA'
		,@value						= @var
	END
GO


--PUBLICAR PROJETO
DECLARE @ProjectBinary varbinary(max)
DECLARE @operation_id bigint
SET @ProjectBinary = (SELECT * FROM OPENROWSET(BULK '\\SERVIDOR\Publicacao01\SSIS\NOME_PROJETO.ispac', SINGLE_BLOB) AS BinaryData)

EXEC [SSISDB].[catalog].[deploy_project]
 @folder_name				= 'NOME_PASTA'
,@project_name				= 'NOME_PROJETO'
,@Project_Stream			= @ProjectBinary
,@operation_id				= @operation_id OUT
GO


--CRIAR REFERÊNCIA AO AMBIENTE
DECLARE @reference_id BIGINT

SELECT  @reference_id = ENV.reference_id
FROM		SSISDB.catalog.projects					AS PRO WITH (NOLOCK)
INNER JOIN	SSISDB.catalog.environment_references	AS ENV WITH (NOLOCK) ON ENV.project_id = PRO.project_id
WHERE	PRO.name			= 'NOME_PROJETO'
	AND ENV.reference_type	= 'R'

--SELECT @reference_id

IF(@reference_id IS NULL)
	EXEC [SSISDB].[catalog].[create_environment_reference]
	 @folder_name				= N'NOME_PASTA'
	,@project_name				= N'NOME_PROJETO'
	,@environment_name			= N'NOME_AMBIENTE'
	,@reference_type			= R
	,@reference_id				= @reference_id OUTPUT
GO


--CONFIGURAR PARÂMETROS

--Parâmetros de Referência

EXEC [SSISDB].[catalog].[set_object_parameter_value]
 @object_type				= 20
,@folder_name				= N'NOME_PASTA'
,@project_name				= N'NOME_PROJETO'
,@parameter_name			= N'Parametro01'
,@parameter_value			= N'Variavel01'
--,@object_name				= N''
,@value_type				= R

EXEC [SSISDB].[catalog].[set_object_parameter_value]
 @object_type				= 30
,@folder_name				= N'NOME_PASTA'
,@project_name				= N'NOME_PROJETO'
,@parameter_name			= N'Parametro02'
,@parameter_value			= N'Variavel02'
,@object_name				= N'NOME_PACOTE.dtsx'
,@value_type				= R
GO

--Parâmetros de Valor

DECLARE @parameter_value sql_variant

SET @parameter_value = CONVERT(DATETIME, '1900-01-01 00:00:00.000')

EXEC [SSISDB].[catalog].[set_object_parameter_value]
 @object_type				= 20
,@folder_name				= N'NOME_PASTA'
,@project_name				= N'NOME_PROJETO'
,@parameter_name			= N'Parametro03'
,@parameter_value			= @parameter_value
,@object_name				= N'NOME_PROJETO'
,@value_type				= V

EXEC [SSISDB].[catalog].[set_object_parameter_value]
 @object_type				= 30
,@folder_name				= N'NOME_PASTA'
,@project_name				= N'NOME_PROJETO'
,@parameter_name			= N'Parametro04'
,@parameter_value			= 190001
,@object_name				= N'NOME_PACOTE.dtsx'
,@value_type				= V
GO

--VALIDAR PROJETO
DECLARE @validation_id bigint
EXEC [SSISDB].[catalog].[validate_project]
 @folder_name				= N'NOME_PASTA'
,@project_name				= N'NOME_PROJETO'
,@validate_type				= F
,@validation_id				= @validation_id OUTPUT
,@use32bitruntime			= False
,@environment_scope			= A
,@reference_id				= NULL
GO