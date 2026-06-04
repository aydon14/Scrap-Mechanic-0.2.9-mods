#include "base_transform.h"
#include "base_texture.h"
#include "base_rendering.h"
#include "base_math.h"
#include "base_light.h"

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
	float2 uv			 	: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 vPosition  		: SV_Position;
    float2 uv 				: TEXCOORD0;
};

Texture2D		tGBuffer0	: register( t0 );
Texture2D		tGBuffer1	: register( t1 );
Texture2D		tGBuffer2	: register( t2 );
Texture2D		tDepth		: register( t3 );
Texture2D		tShadow 	: register( t4 );
Texture2D		tGradient 	: register( t5 );
TextureCube		tEnvMap		: register( t6 );


// -------------------------------------------------------------------
// vertex functions
// -------------------------------------------------------------------

VS_OUTPUT mainVS( VS_INPUT input )
{
	VS_OUTPUT output;
	output.vPosition = float4( input.vLocalPosition.xy * 2.0 - 1.0, 1.0, 1.0 );
	output.uv = input.uv;
	output.uv.y = 1.0 - output.uv.y;

    return output;
};

float4 mainPS( VS_OUTPUT input ) : SV_Target0
{
	float2 dims = getDims( tDepth );
	float2 uvAligned = input.vPosition.xy / dims;

	float2 vPackedNormal = PointSampleCC( tGBuffer1, uvAligned ).rg;
	float fDepth = PointSampleCC( tDepth, uvAligned ).r;
	float fShadow = PointSampleCC( tShadow, uvAligned ).r;

	float3 vAlbedo = PointSampleCC( tGBuffer0, uvAligned ).rgb;
	float3 vReflectGlossMaterial = PointSampleCC( tGBuffer2, uvAligned ).rga;

	float3 vViewSpacePosition = depthAndUvToViewPosition( fDepth, uvAligned, projectionToView );

	float3 vNormal = unpackNormal( vPackedNormal );
	float3 vEyeDir = normalize( -vViewSpacePosition );
	float3 vReflectDir = reflect( vEyeDir, vNormal );
	vReflectDir = mul( (float3x3)viewToWorld, vReflectDir );

	//TODO: Do in texture loading
	float3x3 rotN = float3x3( -1, 0, 0, 0, 0, -1, 0, -1, 0 );
	vReflectDir = mul( rotN, vReflectDir );

	float fDiffuse = max( dot( vNormal, -vSunDirectionView.xyz ), 0.0 ) * fShadow;
	float3 vLight = 2.0 * LinearSampleCC( tGradient, float2( fDiffuse, 0.5 ) ).rgb * vAlbedo;

	float fGlossIntensity = vReflectGlossMaterial.r * vReflectGlossMaterial.g * 2.0;
	float fGlossPower = mad( vReflectGlossMaterial.g * vReflectGlossMaterial.g, 750.0, 35.0 );

	float3 vHalfAngleDir = normalize( -vSunDirectionView.xyz + vEyeDir );
	float fNdotH = max( 0.0, dot( vHalfAngleDir, vNormal ) );
	float fSpecular = pow( fNdotH, fGlossPower ) * fShadow;

	float fRim = clamp( pow( 1.0 - abs( dot( vEyeDir, vNormal ) ), 2.0 ) * 0.5, 0.0, 1.0 );

	//float3 vGold = float3( 1.0, 0.7, 0.2 );
	float3 vEnvMap = tEnvMap.SampleLevel( LinearClampClamp, vReflectDir, mad( vReflectGlossMaterial.g, -5, 5 ) ).rgb;
	vLight += mad( fRim, 0.175, vReflectGlossMaterial.r ) * vEnvMap;
	vLight += fSpecular * fGlossIntensity;
	//vLight += mad( vReflectGlossMaterial.r, 0.5, 0.5 ) * vReflectGlossMaterial.g * fSpecular;

	return float4( vLight, 1.0 );
}
