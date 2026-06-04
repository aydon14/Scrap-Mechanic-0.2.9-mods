#include "base_transform.h"
#include "base_texture.h"
#include "base_rendering.h"
#include "base_math.h"
#include "base_light.h"

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
};

struct VS_OUTPUT
{
    float4 vPosition								: SV_Position;
	nointerpolation float3 vSpotPosition			: POSITION1;
	nointerpolation float  fCosCone					: CONE0;
	nointerpolation float3 vSpotDirection			: DIRECTION0;
	nointerpolation float  fCosCutoff				: CONE1;
	nointerpolation float3 vColor					: COLOR0;
	nointerpolation float  fRange					: RANGE0;
};

Texture2D		tGBuffer0	: register( t0 );
Texture2D		tGBuffer1	: register( t1 );
Texture2D		tGBuffer2	: register( t2 );
Texture2D		tDepth		: register( t3 );

// -------------------------------------------------------------------
// vertex functions
// -------------------------------------------------------------------

static const float fAngleBias = 1.036;

VS_OUTPUT mainVS( VS_INPUT input, in uint vertexID : SV_VertexID, in uint instanceID : SV_InstanceID )
{
	SpotLight spotLight = vecSpotLights[instanceID];

	float3 vPosition = spotLight.vPositionCone.xyz;
	float  fConeAngle = spotLight.vPositionCone.w;
	float3 vDirection = spotLight.vDirectionRange.xyz;
	float  fRange = spotLight.vDirectionRange.w;
	float3 vColor = spotLight.vColorCutoff.xyz;
	float  fCutoffAngle = spotLight.vColorCutoff.w;

	float3 vNonParallel = float3( -vDirection.z, vDirection.x, vDirection.y );

	float4 vZAxis = float4( vDirection, 0.0 );
	float4 vXAxis = float4( normalize( cross( vNonParallel.xyz, vZAxis.xyz ) ), 0.0 );
	float4 vYAxis = float4( cross( vZAxis.xyz, vXAxis.xyz ), 0.0 );
	float4 vTranslation = float4( vPosition, 1.0 );

	float4x4 localToWorldTranspose = float4x4( vXAxis, vYAxis, vZAxis, vTranslation );

	float3 vScale = float3( tan( fCutoffAngle * fAngleBias ).xx, 1.0 ) * fRange;

	VS_OUTPUT output;
	output.vPosition = mul( float4( input.vLocalPosition.xyz * vScale, 1.0 ), localToWorldTranspose );
	output.vPosition = mul( worldToView, output.vPosition );
	output.vPosition = mul( viewToProjection, output.vPosition );

	output.vSpotPosition = mul( worldToView, float4( vPosition, 1.0 ) ).xyz;
	output.fCosCone = cos( fConeAngle );
	output.vSpotDirection = mul( worldToView, float4( vDirection, 0.0 ) ).xyz;
	output.fCosCutoff = cos( fCutoffAngle );
	output.vColor = vColor;
	output.fRange = fRange;

    return output;
};

float4 mainPS( VS_OUTPUT input) : SV_Target0
{
	float2 vUv = input.vPosition.xy / getDims( tDepth );
	float2 vPackedNormal = PointSampleCC( tGBuffer1, vUv ).rg;
	float3 vNormal = normalize( unpackNormal( vPackedNormal ) );
	float  fDepth = PointSampleCC( tDepth, vUv ).r;
	float3 vReflectGlossMaterial = PointSampleCC( tGBuffer2, vUv ).rga;
	float3 vViewSpacePosition = depthAndUvToViewPosition( fDepth, vUv, projectionToView );

	float3 vAlbedo = PointSampleCC( tGBuffer0, vUv ).rgb;

	float3 vLight = blinnPhongSpotLightCalc( input.vSpotPosition,
											 input.vSpotDirection,
											 input.vColor,
											 input.fCosCone,
											 input.fCosCutoff,
											 0.0,
											 input.fRange,
											 vViewSpacePosition,
											 vNormal,
											 vAlbedo,
											 vReflectGlossMaterial.r,
											 vReflectGlossMaterial.g );

	return float4( vLight, 1.0 );
}
